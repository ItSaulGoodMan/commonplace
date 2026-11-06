import { env } from 'cloudflare:workers';
import { describe, expect, it } from 'vitest';
import { Client, FakeGoogle, signingKey } from './fake_google';

describe('signing in', () => {
  it('a Google sign-in opens a free account', async () => {
    const app = new Client(new FakeGoogle());
    const account = await app.signIn();
    expect(app.session).toMatch(/^[\w-]+\.[\w-]+$/);
    expect(account).toMatchObject({
      email: 'ana@example.com',
      plan: 'free',
      notesToday: 0,
      notesPerDay: 3,
      plusNotesPerDay: 25,
    });
    expect(account.accountRef).toMatch(/^[0-9a-f]{64}$/);

    const me = await app.send('GET', '/v1/me');
    expect(me.status).toBe(200);
    expect(me.json.account.email).toBe('ana@example.com');
  });

  it('checks real Google tokens: signature, audience, expiry', async () => {
    const google = new FakeGoogle();
    const key = await signingKey('k1');
    google.googleKeys = { keys: [key.jwk] };
    const app = new Client(google);
    const claims = {
      iss: 'https://accounts.google.com',
      aud: 'dev-client',
      sub: '1234567890',
      email: 'real@example.com',
      email_verified: true,
      exp: Math.floor(google.now / 1000) + 600,
    };

    const ok = await app.send('POST', '/v1/session', { idToken: await key.sign(claims) });
    expect(ok.status).toBe(200);
    expect(ok.json.account.email).toBe('real@example.com');

    for (const bad of [
      { ...claims, aud: 'someone-elses-app' },
      { ...claims, exp: Math.floor(google.now / 1000) - 600 },
      { ...claims, iss: 'https://evil.example' },
      { ...claims, email_verified: false },
    ]) {
      const res = await app.send('POST', '/v1/session', { idToken: await key.sign(bad) });
      expect(res.status, JSON.stringify(bad)).toBe(401);
      expect(res.json.error.code).toBe('signed_out');
    }

    const other = await signingKey('k1');
    const forged = await app.send('POST', '/v1/session', { idToken: await other.sign(claims) });
    expect(forged.status).toBe(401);
  });

  it('turns made-up sign-ins away when DEV_FAKES is off', async () => {
    const app = new Client(new FakeGoogle(), { DEV_FAKES: '0' });
    const res = await app.send('POST', '/v1/session', {
      idToken: `dev:${JSON.stringify({ sub: '1', email: 'a@b.c' })}`,
    });
    expect(res.status).toBe(401);
  });

  it('everything else needs a session', async () => {
    const app = new Client(new FakeGoogle());
    expect((await app.send('GET', '/v1/me')).status).toBe(401);
    app.session = 'made.up';
    expect((await app.send('GET', '/v1/me')).status).toBe(401);
    expect((await app.send('GET', '/v1/nope')).status).toBe(404);
  });
});

describe('making notes', () => {
  it('a video becomes a note, costs one note, and leaves nothing behind', async () => {
    const google = new FakeGoogle();
    const app = new Client(google);
    await app.signIn();

    const note = await app.makeNote();
    expect(note.status).toBe(200);
    expect(note.json.note.title).toBe('Salt pasta water like the sea');

    const me = await app.send('GET', '/v1/me');
    expect(me.json.account.notesToday).toBe(1);
    expect([...google.files.values()].every((f) => f.deleted)).toBe(true);
    expect(google.files.get('files/f1')?.bytes).toBe(2048);
    // The shared free key and model do the work.
    const generate = google.geminiCalls('generate');
    expect(generate).toHaveLength(2);
    expect(generate.every((c) => c.key === env.GEMINI_API_KEY)).toBe(true);
    expect(generate[0]!.url).toContain(`/models/${env.GEMINI_MODEL}:generateContent`);
  });

  it('the server, not the app, writes the prompt', async () => {
    const google = new FakeGoogle();
    const app = new Client(google);
    await app.signIn();
    const res = await app.send('POST', '/v1/write', {
      material: 'Caption: costs $& and $1, not more',
      language: 'Serbian',
    });
    expect(res.status).toBe(200);
    const sent = JSON.parse(google.geminiCalls('generate')[0]!.body!);
    const prompt = sent.contents[0].parts[0].text as string;
    expect(prompt).toContain('Turn this saved reel into a note');
    expect(prompt).toContain('Write every field in Serbian.');
    expect(prompt).toContain('costs $& and $1, not more');
    expect(sent.generationConfig.responseMimeType).toBe('application/json');
  });

  it('three free notes a day, then the rest wait for tomorrow', async () => {
    const google = new FakeGoogle();
    const app = new Client(google);
    await app.signIn();
    for (let i = 0; i < 3; i++) expect((await app.makeNote()).status).toBe(200);

    const fourth = await app.uploadVideo();
    expect(fourth.status).toBe(429);
    expect(fourth.json.error.code).toBe('daily_limit');
    expect(fourth.json.error.message).toContain('Commonplace Plus');
    expect(fourth.json.error.retryAfter).toBeGreaterThan(0);

    google.now += 24 * 3_600_000;
    expect((await app.makeNote()).status).toBe(200);
  });

  it('a failed note costs nothing', async () => {
    const google = new FakeGoogle();
    const app = new Client(google);
    await app.signIn();
    google.geminiMode = 'busy';
    const res = await app.makeNote();
    expect(res.status).toBe(503);
    expect(res.json.error.code).toBe('busy');
    const me = await app.send('GET', '/v1/me');
    expect(me.json.account.notesToday).toBe(0);
  });

  it('rewrites and text notes are counted separately', async () => {
    const app = new Client(new FakeGoogle());
    await app.signIn();
    const text = await app.send('POST', '/v1/write', { material: 'A tip I heard' });
    expect(text.status).toBe(200);
    const rewrite = await app.send('POST', '/v1/write', {
      material: 'A tip I heard',
      rewrite: true,
    });
    expect(rewrite.status).toBe(200);
    const me = await app.send('GET', '/v1/me');
    expect(me.json.account.notesToday).toBe(1);
  });

  it("can't use someone else's files or a made-up ticket for free", async () => {
    const google = new FakeGoogle();
    const ana = new Client(google);
    await ana.signIn('1', 'ana@example.com');
    const upload = await ana.uploadVideo();

    const ben = new Client(google);
    await ben.signIn('2', 'ben@example.com');
    const stolen = await ben.send('POST', '/v1/extract', { files: [upload.json.file.name] });
    expect(stolen.status).toBe(404);

    await ben.send('POST', '/v1/write', { material: 'x', ticket: 'made-up' });
    const me = await ben.send('GET', '/v1/me');
    expect(me.json.account.notesToday).toBe(1);
  });

  it('refuses what it should not upload', async () => {
    const app = new Client(new FakeGoogle());
    await app.signIn();
    const pdf = await app.send('POST', '/v1/files', new Uint8Array(10), {
      'Content-Type': 'application/pdf',
    });
    expect(pdf.status).toBe(400);
    const huge = await app.send('POST', '/v1/files', new Uint8Array(1), {
      'Content-Type': 'video/mp4',
      'Content-Length': String(200 * 1024 * 1024),
    });
    expect(huge.status).toBe(413);
  });
});

describe("when the free key's day is used up", () => {
  it('everyone on the free key waits until it resets, without asking Gemini again', async () => {
    const google = new FakeGoogle();
    const ana = new Client(google);
    await ana.signIn('1', 'ana@example.com');
    google.geminiMode = 'perDay';

    const res = await ana.makeNote();
    expect(res.status).toBe(429);
    expect(res.json.error.code).toBe('shared_limit');

    google.geminiMode = 'ok';
    const ben = new Client(google);
    await ben.signIn('2', 'ben@example.com');
    const before = google.calls.length;
    const blocked = await ben.uploadVideo();
    expect(blocked.status).toBe(429);
    expect(blocked.json.error.code).toBe('shared_limit');
    expect(google.calls.length).toBe(before);

    // Nobody was charged for it.
    expect((await ana.send('GET', '/v1/me')).json.account.notesToday).toBe(0);

    google.now += 24 * 3_600_000;
    expect((await ben.makeNote()).status).toBe(200);
  });
});

describe('Commonplace Plus', () => {
  it('a Play purchase gives more notes a day and moves to the paid key', async () => {
    const google = new FakeGoogle();
    const app = new Client(google, {
      GEMINI_PAID_API_KEY: 'AIzaTESTPAIDKEY',
    });
    const account = await app.signIn();
    const bought = await app.send('POST', '/v1/plus', {
      productId: 'commonplace_plus',
      purchaseToken: `fake-${account.accountRef}-1`,
    });
    expect(bought.status).toBe(200);
    expect(bought.json.account).toMatchObject({ plan: 'plus', notesPerDay: 25 });

    for (let i = 0; i < 4; i++) expect((await app.makeNote()).status).toBe(200);
    expect(google.geminiCalls('generate').every((c) => c.key === 'AIzaTESTPAIDKEY')).toBe(true);
    expect(google.geminiCalls('generate')[0]!.url).toContain(`/models/${env.GEMINI_PAID_MODEL}:`);
  });

  it('without a paid key, Plus still works on the free key', async () => {
    const google = new FakeGoogle();
    const app = new Client(google);
    const account = await app.signIn();
    await app.send('POST', '/v1/plus', { purchaseToken: `fake-${account.accountRef}-1` });
    expect((await app.makeNote()).status).toBe(200);
    expect(google.geminiCalls('generate')[0]!.key).toBe(env.GEMINI_API_KEY);
  });

  it("one purchase can't unlock two accounts", async () => {
    const google = new FakeGoogle();
    const ana = new Client(google);
    const anaAccount = await ana.signIn('1', 'ana@example.com');
    const token = `fake-${anaAccount.accountRef}-1`;
    expect((await ana.send('POST', '/v1/plus', { purchaseToken: token })).status).toBe(200);

    const ben = new Client(google);
    await ben.signIn('2', 'ben@example.com');
    const res = await ben.send('POST', '/v1/plus', { purchaseToken: token });
    expect(res.status).toBe(402);
    expect(res.json.error.code).toBe('purchase_invalid');
  });

  it('checks real purchases with Google Play, and again after they lapse', async () => {
    const google = new FakeGoogle();
    const key = await signingKey('sa');
    const serviceAccount = JSON.stringify({
      client_email: 'play@commonplace.iam.gserviceaccount.com',
      private_key: await key.pkcs8Pem(),
    });
    const app = new Client(google, { DEV_FAKES: '0', PLAY_SERVICE_ACCOUNT: serviceAccount });
    // DEV_FAKES is off, so sign in with a real-looking Google token.
    const signIn = await signingKey('g1');
    google.googleKeys = { keys: [signIn.jwk] };
    const session = await app.send('POST', '/v1/session', {
      idToken: await signIn.sign({
        iss: 'accounts.google.com',
        aud: 'dev-client',
        sub: '42',
        email: 'buyer@example.com',
        email_verified: true,
        exp: Math.floor(google.now / 1000) + 600,
      }),
    });
    app.session = session.json.session;
    const ref = session.json.account.accountRef as string;

    const expiry = new Date(google.now + 3 * 86_400_000).toISOString();
    google.playAnswer = {
      status: 200,
      body: {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [{ productId: 'commonplace_plus', expiryTime: expiry, autoRenewingPlan: {} }],
        externalAccountIdentifiers: { obfuscatedExternalAccountId: ref },
        acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      },
    };
    const bought = await app.send('POST', '/v1/plus', {
      productId: 'commonplace_plus',
      purchaseToken: 'real-play-token-abcdef',
    });
    expect(bought.status).toBe(200);
    expect(bought.json.account.plan).toBe('plus');
    const verify = google.calls.find((c) => c.url.includes('/subscriptionsv2/tokens/'));
    expect(verify?.url).toContain(
      '/applications/com.nemanjapejic.commonplace/purchases/subscriptionsv2/tokens/real-play-token-abcdef',
    );

    // Four days later the period is over and Play says it expired.
    google.now += 4 * 86_400_000;
    google.playAnswer = {
      status: 200,
      body: {
        subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED',
        lineItems: [{ productId: 'commonplace_plus', expiryTime: expiry }],
      },
    };
    const me = await app.send('GET', '/v1/me');
    expect(me.json.account.plan).toBe('free');

    // A purchase made by another account is refused.
    google.playAnswer = {
      status: 200,
      body: {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [{ productId: 'commonplace_plus', expiryTime: new Date(google.now + 86_400_000).toISOString() }],
        externalAccountIdentifiers: { obfuscatedExternalAccountId: 'f'.repeat(64) },
      },
    };
    const theirs = await app.send('POST', '/v1/plus', { purchaseToken: 'someone-elses-token' });
    expect(theirs.status).toBe(402);
  });
});

describe('deleting the account', () => {
  it('removes everything and signs out', async () => {
    const google = new FakeGoogle();
    const app = new Client(google);
    await app.signIn();
    await app.makeNote();
    const res = await app.send('DELETE', '/v1/me');
    expect(res.status).toBe(200);
    expect((await app.send('GET', '/v1/me')).status).toBe(401);
    const rows = await env.DB.prepare('SELECT COUNT(*) AS n FROM usage').first<{ n: number }>();
    expect(rows?.n).toBe(0);
  });
});
