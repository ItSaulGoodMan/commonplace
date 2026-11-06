import { describe, expect, it } from 'vitest';
import { nextPacificMidnight, nextUtcMidnight, parseDurationSeconds, utcDay } from '../src/time';
import { parseJsonObject } from '../src/gemini';

describe('time', () => {
  it('days and resets', () => {
    const t = Date.UTC(2026, 10, 6, 23, 30);
    expect(utcDay(t)).toBe('2026-11-06');
    expect(nextUtcMidnight(t)).toBe(Date.UTC(2026, 10, 7));
    // 23:30 UTC is 15:30 in Los Angeles (PST, UTC-8): 8.5 hours to midnight.
    expect(nextPacificMidnight(t)).toBe(Date.UTC(2026, 10, 7, 8, 0));
    expect(parseDurationSeconds('12s')).toBe(12);
    expect(parseDurationSeconds('1.5s')).toBe(1.5);
    expect(parseDurationSeconds('soon')).toBeUndefined();
  });

  it('reads model JSON, with or without code fences', () => {
    expect(parseJsonObject('{"a":1}')).toEqual({ a: 1 });
    expect(parseJsonObject('```json\n{"a":1}\n```')).toEqual({ a: 1 });
    expect(() => parseJsonObject('no json here')).toThrow();
  });
});
