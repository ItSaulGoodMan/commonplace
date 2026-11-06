import { env } from 'cloudflare:workers';
import { describe, expect, it } from 'vitest';
import { costMicroUsd, parseSeconds, usageFrom, videoPlan } from '../src/strategy';
import { Client, FakeGoogle } from './fake_google';

describe('watching and paying', () => {
  it('watches reels closely and long videos sparsely', () => {
    expect(videoPlan(null)).toEqual({ fps: 1 });
    expect(videoPlan(45)).toEqual({ fps: 1 });
    expect(videoPlan(150)).toEqual({ fps: 0.5 });
    expect(videoPlan(1200)).toEqual({ fps: 0.25, endOffset: '600s' });
    expect(parseSeconds('12.5s')).toBe(12.5);
    expect(parseSeconds('30')).toBe(30);
    expect(parseSeconds('soon')).toBeNull();
  });

  it('prices a request from Gemini\'s own token counts', () => {
    const usage = usageFrom({
      promptTokenCount: 6000,
      candidatesTokenCount: 700,
      thoughtsTokenCount: 100,
      promptTokensDetails: [{ modality: 'AUDIO', tokenCount: 1900 }],
    });
    expect(usage).toEqual({ input: 4100, audioInput: 1900, output: 800 });
    // Flash-Lite: $0.30 in, $2.50 out per million = 0.38 cents.
    expect(costMicroUsd(usage, { input: 0.3, audioInput: 0.3, output: 2.5 })).toBe(3800);
  });
});

describe('one request per note', () => {
  it('watches once and returns what it read and the note', async () => {
    const google = new FakeGoogle();
    const app = new Client(google);
    await app.signIn();
    const res = await app.makeNoteInOne('Salt it like the sea');
    expect(res.status).toBe(200);
    expect(res.json.extraction.transcript).toContain('pasta water');
    expect(res.json.note.title).toBe('Salt pasta water like the sea');
    expect(res.json.note.transcript).toBeUndefined();

    const generate = google.geminiCalls('generate');
    expect(generate).toHaveLength(1);
    const sent = JSON.parse(generate[0]!.body!);
    expect(sent.generationConfig.thinkingConfig).toEqual({ thinkingLevel: 'MINIMAL' });
    expect(sent.generationConfig.maxOutputTokens).toBe(8192);
    const parts = sent.contents[0].parts;
    expect(parts[0].fileData).toBeDefined();
    expect(parts[0].videoMetadata, 'a reel is watched at the default rate').toBeUndefined();
    expect(parts[1].text).toContain('The owner added this caption');
    expect(parts[1].text).toContain('Salt it like the sea');

    expect((await app.send('GET', '/v1/me')).json.account.notesToday).toBe(1);
    expect([...google.files.values()].every((f) => f.deleted)).toBe(true);
  });

  it('long videos are watched more sparsely', async () => {
    const google = new FakeGoogle();
    const app = new Client(google);
    await app.signIn();

    google.videoSeconds = 150;
    await app.makeNoteInOne();
    google.videoSeconds = 1200;
    await app.makeNoteInOne();

    const metas = google
      .geminiCalls('generate')
      .map((c) => JSON.parse(c.body!).contents[0].parts[0].videoMetadata);
    expect(metas).toEqual([{ fps: 0.5 }, { fps: 0.25, endOffset: '600s' }]);
  });

  it('a model that refuses the thinking setting still makes the note', async () => {
    const google = new FakeGoogle();
    google.rejectThinking = true;
    const app = new Client(google);
    await app.signIn();
    const res = await app.makeNoteInOne();
    expect(res.status).toBe(200);
    const generate = google.geminiCalls('generate');
    expect(generate).toHaveLength(2);
    expect(generate[1]!.body).not.toContain('thinkingConfig');
  });
});

describe('every subscriber stays profitable', () => {
  it('free accounts never touch the paid key or cost anything', async () => {
    const google = new FakeGoogle();
    const app = new Client(google, { GEMINI_PAID_API_KEY: 'AIzaTESTPAIDKEY' });
    await app.signIn();
    await app.makeNoteInOne();
    expect(google.geminiCalls('generate').every((c) => c.key === env.GEMINI_API_KEY)).toBe(true);
    const row = await env.DB.prepare('SELECT micro_usd, notes FROM spend').first<{
      micro_usd: number;
      notes: number;
    }>();
    expect(row).toEqual({ micro_usd: 0, notes: 1 });
  });

  it('a subscriber moves to the free key once the month\'s budget is spent', async () => {
    const google = new FakeGoogle();
    // Each note costs 3800 micro-dollars here; the budget covers just over one.
    const app = new Client(google, {
      GEMINI_PAID_API_KEY: 'AIzaTESTPAIDKEY',
      PLUS_MONTHLY_BUDGET_USD: '0.005',
    });
    const account = await app.signIn();
    await app.send('POST', '/v1/plus', { purchaseToken: `fake-${account.accountRef}-1` });

    for (let i = 0; i < 3; i++) expect((await app.makeNoteInOne()).status).toBe(200);
    expect(google.geminiCalls('generate').map((c) => c.key)).toEqual([
      'AIzaTESTPAIDKEY',
      'AIzaTESTPAIDKEY',
      env.GEMINI_API_KEY,
    ]);
    const row = await env.DB.prepare('SELECT micro_usd FROM spend').first<{ micro_usd: number }>();
    expect(row?.micro_usd, 'only paid-key notes cost money').toBe(7600);

    // A new month, a new budget.
    google.now += 31 * 86_400_000;
    await app.makeNoteInOne();
    expect(google.geminiCalls('generate').at(-1)!.key).toBe('AIzaTESTPAIDKEY');
  });
});

describe('numbers for the owner', () => {
  it('shows today and this month, only with the admin token', async () => {
    const google = new FakeGoogle();
    const token = 'admin-token-for-tests-0123456789';
    const app = new Client(google, { ADMIN_TOKEN: token });
    await app.signIn();
    await app.makeNoteInOne();

    const owner = new Client(google, { ADMIN_TOKEN: token });
    expect((await owner.send('GET', '/v1/admin/stats')).status).toBe(404);
    owner.session = 'wrong-token-but-long-enough-xx';
    expect((await owner.send('GET', '/v1/admin/stats')).status).toBe(404);
    owner.session = token;
    const res = await owner.send('GET', '/v1/admin/stats');
    expect(res.status).toBe(200);
    expect(res.json).toMatchObject({
      today: { notes: 1, activeUsers: 1 },
      month: { notes: 1, paidKeySpendUsd: 0 },
      users: 1,
      plusUsers: 0,
      freeKeyUsedUpUntil: null,
    });
  });
});
