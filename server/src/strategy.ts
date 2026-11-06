/**
 * How the server spends Gemini tokens: how closely to watch a video, and
 * what each request cost.
 */

/** How to watch one video, by its length. */
export interface VideoPlan {
  /** Frames per second Gemini looks at. 1 is Gemini's default. */
  fps: number;
  /** Only the first part is watched, e.g. "600s". */
  endOffset?: string;
}

/**
 * Reels (up to a minute and a half) are watched at one frame a second, so a
 * caption that flashes by isn't missed. Longer videos are mostly talk, where
 * the sound carries the content: fewer frames, and very long ones only the
 * first ten minutes. Sound is always heard in full within that window.
 */
export function videoPlan(durationSeconds: number | null): VideoPlan {
  if (durationSeconds === null || durationSeconds <= 90) return { fps: 1 };
  if (durationSeconds <= 180) return { fps: 0.5 };
  return { fps: 0.25, endOffset: '600s' };
}

/** `"12.5s"`, `"12.5"` or `12.5` to seconds; null when it can't tell. */
export function parseSeconds(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value !== 'string') return null;
  const m = /^\s*(\d+(?:\.\d+)?)\s*s?\s*$/.exec(value);
  return m ? Number(m[1]) : null;
}

/** Tokens one generateContent request used, from its `usageMetadata`. */
export interface TokenUsage {
  input: number;
  audioInput: number;
  /** Includes thinking, which Google bills as output. */
  output: number;
}

export function usageFrom(metadata: unknown): TokenUsage {
  const m = (metadata ?? {}) as {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
    thoughtsTokenCount?: number;
    promptTokensDetails?: { modality?: string; tokenCount?: number }[];
  };
  const prompt = m.promptTokenCount ?? 0;
  const audio = (m.promptTokensDetails ?? [])
    .filter((d) => d.modality === 'AUDIO')
    .reduce((sum, d) => sum + (d.tokenCount ?? 0), 0);
  return {
    input: Math.max(0, prompt - audio),
    audioInput: audio,
    output: (m.candidatesTokenCount ?? 0) + (m.thoughtsTokenCount ?? 0),
  };
}

/** USD per million tokens. */
export interface Prices {
  input: number;
  audioInput: number;
  output: number;
}

/**
 * Cost in millionths of a dollar. Handy coincidence: a price in dollars per
 * million tokens is exactly micro-dollars per token.
 */
export function costMicroUsd(usage: TokenUsage, prices: Prices): number {
  return Math.ceil(
    usage.input * prices.input +
      usage.audioInput * prices.audioInput +
      usage.output * prices.output,
  );
}

export function addUsage(a: TokenUsage, b: TokenUsage): TokenUsage {
  return {
    input: a.input + b.input,
    audioInput: a.audioInput + b.audioInput,
    output: a.output + b.output,
  };
}

export const noUsage: TokenUsage = { input: 0, audioInput: 0, output: 0 };
