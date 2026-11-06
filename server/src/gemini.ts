import { ApiError, log, logError } from './http';
import { parseSeconds, type TokenUsage, usageFrom } from './strategy';
import { parseDurationSeconds } from './time';
import type { Deps } from './deps';

/** Which Gemini project pays: the shared free key, or the paid key for Plus. */
export type Pool = 'free' | 'paid';

export interface GeminiFile {
  name: string;
  uri: string;
  mimeType: string;
  state: string;
}

/** The free key ran out for the day: everyone on the free pool waits. */
export class SharedLimitError extends ApiError {
  constructor(readonly resetsAt: number | null) {
    super(
      'shared_limit',
      "Commonplace has used today's free AI time. Your notes will be made tomorrow.",
    );
    this.name = 'SharedLimitError';
  }
}

interface GoogleErrorBody {
  error?: {
    code?: number;
    status?: string;
    message?: string;
    details?: {
      '@type'?: string;
      retryDelay?: string;
      violations?: { quotaId?: string }[];
    }[];
  };
}

export interface GenerateOptions {
  /** MINIMAL, LOW, MEDIUM or HIGH; empty leaves the model's default. */
  thinkingLevel?: string;
  /** Caps what a runaway answer can cost. */
  maxOutputTokens?: number;
}

/** Thin REST client for the parts of the Gemini API the notes need. */
export class Gemini {
  constructor(
    private readonly base: string,
    private readonly key: string,
    readonly model: string,
    private readonly deps: Deps,
  ) {
    if (!key) throw new ApiError('server', 'The server is not set up yet.');
  }

  /**
   * Streams a file into the Files API without holding it in memory.
   * `size` must be the exact byte count of [body].
   */
  async upload(
    body: ReadableStream<Uint8Array>,
    size: number,
    mimeType: string,
    displayName: string,
  ): Promise<GeminiFile> {
    const start = await this.deps.fetch(`${this.base}/upload/v1beta/files`, {
      method: 'POST',
      headers: {
        'x-goog-api-key': this.key,
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': String(size),
        'X-Goog-Upload-Header-Content-Type': mimeType,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ file: { display_name: displayName } }),
    });
    if (!start.ok) await this.fail(start);
    const uploadUrl = start.headers.get('x-goog-upload-url');
    if (!uploadUrl) throw new ApiError('busy', 'Gemini did not accept the upload. Try again.', 10);

    const { readable, writable } = new FixedLengthStream(size);
    const pipe = body.pipeTo(writable);
    const done = await this.deps.fetch(uploadUrl, {
      method: 'POST',
      headers: {
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
      },
      body: readable,
    });
    await pipe;
    if (!done.ok) await this.fail(done);
    const { file } = (await done.json()) as { file?: Partial<GeminiFile> };
    if (!file?.name || !file.uri) {
      throw new ApiError('busy', 'Gemini did not accept the upload. Try again.', 10);
    }
    return {
      name: file.name,
      uri: file.uri,
      mimeType: file.mimeType ?? mimeType,
      state: file.state ?? 'PROCESSING',
    };
  }

  /**
   * Waits until Gemini has processed a video (images are ready at once).
   * Returns how many times it asked, and the video's length if Gemini said.
   */
  async waitUntilActive(
    name: string,
    attempts = 20,
    intervalMs = 2000,
  ): Promise<{ polls: number; durationSeconds: number | null }> {
    for (let i = 0; i < attempts; i++) {
      const response = await this.deps.fetch(`${this.base}/v1beta/${name}`, {
        headers: { 'x-goog-api-key': this.key },
      });
      if (!response.ok) await this.fail(response);
      const { state, videoMetadata } = (await response.json()) as {
        state?: string;
        videoMetadata?: { videoDuration?: unknown };
      };
      if (state === 'ACTIVE') {
        return { polls: i + 1, durationSeconds: parseSeconds(videoMetadata?.videoDuration) };
      }
      if (state === 'FAILED') {
        throw new ApiError('blocked', "Gemini couldn't read this video. Try a different file.");
      }
      await this.deps.sleep(intervalMs);
    }
    throw new ApiError('busy', 'Gemini is still processing the video. Try again in a minute.', 60);
  }

  async deleteFile(name: string): Promise<void> {
    try {
      await this.deps.fetch(`${this.base}/v1beta/${name}`, {
        method: 'DELETE',
        headers: { 'x-goog-api-key': this.key },
      });
    } catch (e) {
      logError('gemini_delete_failed', { name, error: String(e) });
    }
  }

  /**
   * Sends [parts] and returns the model's JSON answer, constrained to
   * [schema], with the tokens it used.
   */
  async generateJson(
    parts: Record<string, unknown>[],
    schema: unknown,
    options: GenerateOptions = {},
  ): Promise<{ json: Record<string, unknown>; usage: TokenUsage }> {
    const send = (thinking: boolean): Promise<Response> =>
      this.deps.fetch(`${this.base}/v1beta/models/${this.model}:generateContent`, {
        method: 'POST',
        headers: {
          'x-goog-api-key': this.key,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: JSON.stringify({
          contents: [{ role: 'user', parts }],
          generationConfig: {
            responseMimeType: 'application/json',
            responseJsonSchema: schema,
            ...(options.maxOutputTokens ? { maxOutputTokens: options.maxOutputTokens } : {}),
            ...(thinking && options.thinkingLevel
              ? { thinkingConfig: { thinkingLevel: options.thinkingLevel } }
              : {}),
          },
        }),
      });
    let response = await send(true);
    if (response.status === 400 && options.thinkingLevel) {
      // A model that doesn't take this thinking level (or any) says so with
      // a 400. Better a note at the default level than no note.
      const text = await response.clone().text();
      if (/thinking/i.test(text)) {
        log('gemini_thinking_rejected', { model: this.model, level: options.thinkingLevel });
        response = await send(false);
      }
    }
    if (!response.ok) await this.fail(response);
    const body = (await response.json()) as {
      usageMetadata?: unknown;
      candidates?: {
        finishReason?: string;
        content?: { parts?: { text?: string; thought?: boolean }[] };
      }[];
      promptFeedback?: { blockReason?: string };
    };
    const candidate = body.candidates?.[0];
    if (!candidate) {
      if (body.promptFeedback?.blockReason) {
        throw new ApiError('blocked', 'Gemini declined to read this one.');
      }
      throw new ApiError('busy', 'Gemini sent back nothing. Try again.', 10);
    }
    const finish = candidate.finishReason;
    if (
      finish === 'SAFETY' ||
      finish === 'RECITATION' ||
      finish === 'PROHIBITED_CONTENT' ||
      finish === 'BLOCKLIST'
    ) {
      throw new ApiError('blocked', 'Gemini declined to read this one.');
    }
    const text = (candidate.content?.parts ?? [])
      .filter((p) => p.thought !== true)
      .map((p) => p.text ?? '')
      .join('');
    if (!text.trim()) throw new ApiError('busy', 'Gemini sent back nothing. Try again.', 10);
    return { json: parseJsonObject(text), usage: usageFrom(body.usageMetadata) };
  }

  private async fail(response: Response): Promise<never> {
    let body: GoogleErrorBody = {};
    try {
      body = (await response.json()) as GoogleErrorBody;
    } catch {
      // Not JSON; the status says enough.
    }
    const status = response.status;
    const message = body.error?.message ?? '';
    const details = body.error?.details ?? [];
    logError('gemini_error', { status, googleStatus: body.error?.status, message });

    if (status === 429) {
      const perDay = details.some((d) =>
        (d.violations ?? []).some((v) => /PerDay/i.test(v.quotaId ?? '')),
      );
      const retry = details
        .map((d) => parseDurationSeconds(d.retryDelay))
        .find((s) => s !== undefined);
      if (perDay) throw new SharedLimitError(null);
      throw new ApiError('busy', 'Gemini is busy right now. Try again in a minute.', retry ?? 60);
    }
    if (status === 413 || /too large|exceeds/i.test(message)) {
      throw new ApiError('too_large', 'This file is too large for Gemini. Try a shorter clip.');
    }
    if (status >= 500) {
      throw new ApiError('busy', 'Gemini is busy right now. Try again in a minute.', 60);
    }
    // 400 bad key, 403, 404 model, FAILED_PRECONDITION region: the server's
    // setup is wrong, not the person's request.
    throw new ApiError('server', 'The AI is not available right now. Try again later.');
  }
}

/** Parses a JSON object out of model text, tolerating code fences. */
export function parseJsonObject(text: string): Record<string, unknown> {
  let t = text.trim();
  if (t.startsWith('```')) {
    t = t.replace(/^```[a-zA-Z]*\s*/, '').replace(/```\s*$/, '');
  }
  const startIndex = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (startIndex < 0 || end <= startIndex) {
    throw new ApiError('busy', 'Gemini sent back something unreadable. Try again.', 10);
  }
  try {
    const parsed: unknown = JSON.parse(t.slice(startIndex, end + 1));
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
  } catch {
    // Falls through.
  }
  throw new ApiError('busy', 'Gemini sent back something unreadable. Try again.', 10);
}
