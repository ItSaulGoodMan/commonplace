import { createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { env } from 'cloudflare:workers';
import { b64url, utf8 } from '../src/crypto';
import type { Deps } from '../src/deps';
import { makeFetch } from '../src/index';

/** Every Google endpoint the server talks to, in memory. */
export class FakeGoogle {
  now = Date.UTC(2026, 10, 6, 9, 0, 0);
  /** What generateContent does next: answer, or fail like Gemini does. */
  geminiMode: 'ok' | 'perDay' | 'busy' = 'ok';
  readonly calls: { url: string; method: string; key: string | null; body?: string }[] = [];
  readonly files = new Map<string, { state: string; polls: number; bytes: number; deleted: boolean }>();
  /** Answer for androidpublisher subscriptionsv2. */
  playAnswer: { status: number; body: unknown } = { status: 404, body: {} };
  googleKeys: { keys: JsonWebKey[] } = { keys: [] };
  /** How long uploaded videos are, as Gemini reports after processing. */
  videoSeconds = 45;
  /** Answer 400 to any thinkingConfig, like a model without that level. */
  rejectThinking = false;
  /** Tokens each generateContent reports using. */
  usage = {
    promptTokenCount: 6000,
    candidatesTokenCount: 700,
    thoughtsTokenCount: 100,
    promptTokensDetails: [
      { modality: 'VIDEO', tokenCount: 3900 },
      { modality: 'AUDIO', tokenCount: 1900 },
      { modality: 'TEXT', tokenCount: 200 },
    ],
  };

  private uploads = 0;

  readonly deps: Deps = {
    now: () => this.now,
    sleep: async () => {},
    fetch: (input, init) => this.fetch(new Request(input, init)),
  };

  geminiCalls(kind: 'generate' | 'upload' | 'poll' | 'delete'): typeof this.calls {
    return this.calls.filter((c) => {
      if (kind === 'generate') return c.url.includes(':generateContent');
      if (kind === 'upload') return c.url.includes('/upload/');
      if (kind === 'delete') return c.method === 'DELETE';
      return c.method === 'GET' && c.url.includes('/v1beta/files/');
    });
  }

  private async fetch(request: Request): Promise<Response> {
    const url = request.url;
    const key = request.headers.get('x-goog-api-key');
    const body =
      request.method === 'POST' && !url.includes('/upload-session/')
        ? await request.clone().text()
        : undefined;
    this.calls.push({ url, method: request.method, key, body });

    if (url === 'https://www.googleapis.com/oauth2/v3/certs') {
      return Response.json(this.googleKeys);
    }
    if (url === 'https://oauth2.googleapis.com/token') {
      return Response.json({ access_token: 'play-access-token', expires_in: 3600 });
    }
    if (url.startsWith('https://androidpublisher.googleapis.com/')) {
      if (request.headers.get('Authorization') !== 'Bearer play-access-token') {
        return new Response('{}', { status: 401 });
      }
      return Response.json(this.playAnswer.body, { status: this.playAnswer.status });
    }

    const base = env.GEMINI_BASE_URL;
    if (url === `${base}/upload/v1beta/files`) {
      const id = `f${++this.uploads}`;
      return new Response('{}', {
        headers: { 'x-goog-upload-url': `${base}/upload-session/${id}` },
      });
    }
    const session = /\/upload-session\/(\w+)$/.exec(url);
    if (session) {
      const bytes = (await request.arrayBuffer()).byteLength;
      const name = `files/${session[1]}`;
      this.files.set(name, { state: 'PROCESSING', polls: 0, bytes, deleted: false });
      return Response.json({
        file: { name, uri: `${base}/v1beta/${name}`, mimeType: 'video/mp4', state: 'PROCESSING' },
      });
    }
    const file = /\/v1beta\/(files\/\w+)$/.exec(url);
    if (file) {
      const f = this.files.get(file[1]!);
      if (!f) return Response.json({ error: { code: 404 } }, { status: 404 });
      if (request.method === 'DELETE') {
        f.deleted = true;
        return Response.json({});
      }
      f.polls++;
      if (f.polls >= 2) f.state = 'ACTIVE';
      return Response.json({
        name: file[1],
        state: f.state,
        videoMetadata: { videoDuration: `${this.videoSeconds}s` },
      });
    }
    if (url.includes(':generateContent')) {
      if (!key?.startsWith('AQ.') && !key?.startsWith('AIza')) {
        return Response.json({ error: { code: 400, message: 'API key not valid.' } }, { status: 400 });
      }
      if (this.geminiMode === 'perDay') {
        return Response.json(
          {
            error: {
              code: 429,
              status: 'RESOURCE_EXHAUSTED',
              message: 'You exceeded your current quota.',
              details: [
                {
                  '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
                  violations: [{ quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier' }],
                },
                { '@type': 'type.googleapis.com/google.rpc.RetryInfo', retryDelay: '3600s' },
              ],
            },
          },
          { status: 429 },
        );
      }
      if (this.rejectThinking && body?.includes('thinkingConfig')) {
        return Response.json(
          { error: { code: 400, message: 'Thinking level is not supported for this model.' } },
          { status: 400 },
        );
      }
      if (this.geminiMode === 'busy') {
        return Response.json({ error: { code: 503, message: 'overloaded' } }, { status: 503 });
      }
      const read = {
        transcript: 'Salt the pasta water until it tastes like the sea.',
        on_screen_text: ['Salt it hard'],
        visual_notes: '',
        language: 'en',
        creator_handle: 'cook.with.ana',
      };
      const note = {
        title: 'Salt pasta water like the sea',
        summary: 'One habit for better pasta.',
        key_points: [{ text: 'Salt the water hard.', highlight: 'Salt the water' }],
        actions: ['Taste the water'],
        topic: 'Cooking',
        tags: ['pasta'],
      };
      const hasMedia = body?.includes('fileData') ?? false;
      const wantsNote = body?.includes('key_points') ?? false;
      const answer = hasMedia && wantsNote ? { ...read, ...note } : hasMedia ? read : note;
      return Response.json({
        candidates: [
          {
            content: { role: 'model', parts: [{ text: JSON.stringify(answer) }] },
            finishReason: 'STOP',
          },
        ],
        usageMetadata: this.usage,
      });
    }
    return new Response(`unexpected ${request.method} ${url}`, { status: 599 });
  }
}

/** Calls the Worker like the app would. */
export class Client {
  session: string | null = null;
  private readonly handler;

  constructor(
    readonly google: FakeGoogle,
    /** Config the test changes, e.g. a lower budget. */
    private readonly overrides: Partial<Record<keyof Env, string>> = {},
  ) {
    this.handler = makeFetch(google.deps);
  }

  async send(
    method: string,
    path: string,
    body?: unknown,
    headers: Record<string, string> = {},
  ): Promise<{ status: number; json: Record<string, any> }> {
    const ctx = createExecutionContext();
    const init: RequestInit = { method, headers: { ...headers } };
    if (body instanceof Uint8Array) {
      init.body = body;
      (init.headers as Record<string, string>)['Content-Length'] ??= String(body.byteLength);
    } else if (body !== undefined) {
      const text = JSON.stringify(body);
      init.body = text;
      (init.headers as Record<string, string>)['Content-Type'] = 'application/json';
      (init.headers as Record<string, string>)['Content-Length'] = String(utf8(text).byteLength);
    }
    if (this.session) {
      (init.headers as Record<string, string>).Authorization = `Bearer ${this.session}`;
    }
    const response = await this.handler(
      new Request(`https://api.test${path}`, init),
      { ...env, ...this.overrides } as Env,
      ctx,
    );
    await waitOnExecutionContext(ctx);
    return { status: response.status, json: (await response.json()) as Record<string, any> };
  }

  async signIn(sub = '1', email = 'ana@example.com'): Promise<Record<string, any>> {
    const res = await this.send('POST', '/v1/session', {
      idToken: `dev:${JSON.stringify({ sub, email, name: 'Ana' })}`,
    });
    this.session = res.json.session as string;
    return res.json.account as Record<string, any>;
  }

  async uploadVideo(bytes = 2048): Promise<{ status: number; json: Record<string, any> }> {
    return this.send('POST', '/v1/files', new Uint8Array(bytes), {
      'Content-Type': 'video/mp4',
      'X-File-Name': 'reel.mp4',
    });
  }

  /** A full note from one video, the way the app does it now. */
  async makeNoteInOne(caption?: string): Promise<{ status: number; json: Record<string, any> }> {
    const up = await this.uploadVideo();
    if (up.status !== 200) return up;
    return this.send('POST', '/v1/note', { files: [up.json.file.name], caption });
  }

  /** A full note from one video: upload, extract, write. */
  async makeNote(): Promise<{ status: number; json: Record<string, any> }> {
    const up = await this.uploadVideo();
    if (up.status !== 200) return up;
    const ex = await this.send('POST', '/v1/extract', { files: [up.json.file.name] });
    if (ex.status !== 200) return ex;
    return this.send('POST', '/v1/write', {
      material: `Spoken:\n${ex.json.extraction.transcript}`,
      ticket: ex.json.ticket,
    });
  }
}

/** An RSA key pair standing in for Google's sign-in keys. */
export async function signingKey(kid: string): Promise<{
  jwk: JsonWebKey;
  sign(claims: Record<string, unknown>): Promise<string>;
  pkcs8Pem(): Promise<string>;
}> {
  const pair = (await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  )) as CryptoKeyPair;
  const jwk = { ...((await crypto.subtle.exportKey('jwk', pair.publicKey)) as JsonWebKey), kid };
  return {
    jwk,
    async sign(claims) {
      const header = b64url(utf8(JSON.stringify({ alg: 'RS256', kid, typ: 'JWT' })));
      const payload = b64url(utf8(JSON.stringify(claims)));
      const sig = await crypto.subtle.sign(
        'RSASSA-PKCS1-v1_5',
        pair.privateKey,
        utf8(`${header}.${payload}`),
      );
      return `${header}.${payload}.${b64url(sig)}`;
    },
    async pkcs8Pem() {
      const der = (await crypto.subtle.exportKey('pkcs8', pair.privateKey)) as ArrayBuffer;
      let binary = '';
      for (const b of new Uint8Array(der)) binary += String.fromCharCode(b);
      return `-----BEGIN PRIVATE KEY-----\n${btoa(binary)}\n-----END PRIVATE KEY-----\n`;
    },
  };
}
