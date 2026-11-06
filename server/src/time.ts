export const DAY_MS = 86_400_000;

/** `YYYY-MM-DD` in UTC: the day each person's limit counts against. */
export function utcDay(now: number): string {
  return new Date(now).toISOString().slice(0, 10);
}

export function nextUtcMidnight(now: number): number {
  return (Math.floor(now / DAY_MS) + 1) * DAY_MS;
}

/** Gemini's free daily limits reset at midnight Pacific time. */
export function nextPacificMidnight(now: number): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Los_Angeles',
    hourCycle: 'h23',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(new Date(now));
  const get = (type: Intl.DateTimeFormatPartTypes): number =>
    Number(parts.find((p) => p.type === type)?.value ?? 0);
  const elapsed = get('hour') * 3600 + get('minute') * 60 + get('second');
  return now - (now % 1000) + (86_400 - elapsed) * 1000;
}

/** Parses Google's `"12s"` / `"1.5s"` durations. */
export function parseDurationSeconds(value: unknown): number | undefined {
  if (typeof value !== 'string') return undefined;
  const m = /^(\d+(?:\.\d+)?)s$/.exec(value.trim());
  return m ? Number(m[1]) : undefined;
}
