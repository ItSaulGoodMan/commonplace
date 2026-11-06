import { sha256Hex } from './crypto';
import type { GoogleUser } from './google';
import { nextUtcMidnight, utcDay } from './time';

export interface Account {
  id: string;
  email: string;
  name: string | null;
  plusUntil: number | null;
  plusProduct: string | null;
  plusToken: string | null;
  plusCheckedAt: number | null;
}

export interface Limits {
  freeNotesPerDay: number;
  plusNotesPerDay: number;
  rewritesPerDay: number;
  uploadsPerDay: number;
}

export type Counter = 'notes' | 'rewrites' | 'uploads';

interface UserRow {
  id: string;
  email: string;
  name: string | null;
  plus_until: number | null;
  plus_product: string | null;
  plus_token: string | null;
  plus_checked_at: number | null;
}

export function limitsFrom(env: {
  FREE_NOTES_PER_DAY: string;
  PLUS_NOTES_PER_DAY: string;
  REWRITES_PER_DAY: string;
  UPLOADS_PER_DAY: string;
}): Limits {
  const n = (v: string, fallback: number): number => {
    const parsed = Number.parseInt(v, 10);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
  };
  return {
    freeNotesPerDay: n(env.FREE_NOTES_PER_DAY, 3),
    plusNotesPerDay: n(env.PLUS_NOTES_PER_DAY, 25),
    rewritesPerDay: n(env.REWRITES_PER_DAY, 20),
    uploadsPerDay: n(env.UPLOADS_PER_DAY, 60),
  };
}

export function isPlus(account: Account, now: number): boolean {
  return account.plusUntil !== null && account.plusUntil > now;
}

export function notesPerDay(account: Account, limits: Limits, now: number): number {
  return isPlus(account, now) ? limits.plusNotesPerDay : limits.freeNotesPerDay;
}

/** A stable, opaque reference the app attaches to Play purchases. */
export function accountRef(userId: string): Promise<string> {
  return sha256Hex(`commonplace-account:${userId}`);
}

export async function upsertUser(db: D1Database, user: GoogleUser, now: number): Promise<void> {
  await db
    .prepare(
      `INSERT INTO users (id, email, name, created_at) VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT(id) DO UPDATE SET email = excluded.email, name = excluded.name`,
    )
    .bind(user.id, user.email, user.name, now)
    .run();
}

export async function findUser(db: D1Database, id: string): Promise<Account | null> {
  const row = await db.prepare('SELECT * FROM users WHERE id = ?1').bind(id).first<UserRow>();
  if (!row) return null;
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    plusUntil: row.plus_until,
    plusProduct: row.plus_product,
    plusToken: row.plus_token,
    plusCheckedAt: row.plus_checked_at,
  };
}

export async function setPlus(
  db: D1Database,
  id: string,
  plus: { until: number | null; product: string; token: string; checkedAt: number },
): Promise<void> {
  await db
    .prepare(
      `UPDATE users SET plus_until = ?2, plus_product = ?3, plus_token = ?4, plus_checked_at = ?5
       WHERE id = ?1`,
    )
    .bind(id, plus.until, plus.product, plus.token, plus.checkedAt)
    .run();
}

export async function usageToday(
  db: D1Database,
  id: string,
  now: number,
): Promise<Record<Counter, number>> {
  const row = await db
    .prepare('SELECT notes, rewrites, uploads FROM usage WHERE user_id = ?1 AND day = ?2')
    .bind(id, utcDay(now))
    .first<Record<Counter, number>>();
  return row ?? { notes: 0, rewrites: 0, uploads: 0 };
}

/**
 * Adds one to today's [counter] if it's still under [limit]. Atomic: two
 * requests at once can't both take the last one. Returns false at the limit.
 */
export async function charge(
  db: D1Database,
  id: string,
  counter: Counter,
  limit: number,
  now: number,
): Promise<boolean> {
  if (limit < 1) return false;
  const initial = { notes: 0, rewrites: 0, uploads: 0, [counter]: 1 };
  const result = await db
    .prepare(
      `INSERT INTO usage (user_id, day, notes, rewrites, uploads) VALUES (?1, ?2, ?3, ?4, ?5)
       ON CONFLICT(user_id, day) DO UPDATE SET ${counter} = ${counter} + 1
       WHERE usage.${counter} < ?6`,
    )
    .bind(id, utcDay(now), initial.notes, initial.rewrites, initial.uploads, limit)
    .run();
  return result.meta.changes === 1;
}

/** Gives back a charge when the work it paid for failed. */
export async function refund(
  db: D1Database,
  id: string,
  counter: Counter,
  now: number,
): Promise<void> {
  await db
    .prepare(
      `UPDATE usage SET ${counter} = ${counter} - 1
       WHERE user_id = ?1 AND day = ?2 AND ${counter} > 0`,
    )
    .bind(id, utcDay(now))
    .run();
}

export async function createTicket(
  db: D1Database,
  userId: string,
  now: number,
): Promise<string> {
  const id = crypto.randomUUID();
  await db
    .prepare('INSERT INTO tickets (id, user_id, expires_at) VALUES (?1, ?2, ?3)')
    .bind(id, userId, now + 86_400_000)
    .run();
  return id;
}

export async function hasTicket(
  db: D1Database,
  userId: string,
  ticket: string,
  now: number,
): Promise<boolean> {
  const row = await db
    .prepare('SELECT 1 AS ok FROM tickets WHERE id = ?1 AND user_id = ?2 AND expires_at > ?3')
    .bind(ticket, userId, now)
    .first<{ ok: number }>();
  return row !== null;
}

export async function useTicket(db: D1Database, ticket: string, now: number): Promise<void> {
  await db.batch([
    db.prepare('DELETE FROM tickets WHERE id = ?1').bind(ticket),
    db.prepare('DELETE FROM tickets WHERE expires_at <= ?1').bind(now),
  ]);
}

export async function getShared(db: D1Database, key: string): Promise<string | null> {
  const row = await db
    .prepare('SELECT value FROM shared_state WHERE key = ?1')
    .bind(key)
    .first<{ value: string }>();
  return row?.value ?? null;
}

export async function setShared(db: D1Database, key: string, value: string): Promise<void> {
  await db
    .prepare(
      `INSERT INTO shared_state (key, value) VALUES (?1, ?2)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
    )
    .bind(key, value)
    .run();
}

/** Everything the app shows about the account. */
export async function accountView(
  db: D1Database,
  account: Account,
  limits: Limits,
  now: number,
): Promise<Record<string, unknown>> {
  const used = await usageToday(db, account.id, now);
  const perDay = notesPerDay(account, limits, now);
  return {
    email: account.email,
    name: account.name,
    plan: isPlus(account, now) ? 'plus' : 'free',
    plusUntil: account.plusUntil && account.plusUntil > now ? account.plusUntil : null,
    notesToday: used.notes,
    notesPerDay: perDay,
    freeNotesPerDay: limits.freeNotesPerDay,
    plusNotesPerDay: limits.plusNotesPerDay,
    resetsAt: nextUtcMidnight(now),
    accountRef: await accountRef(account.id),
  };
}

/** Removes everything stored about an account. Returns its Gemini files. */
export async function deleteAccountData(
  db: D1Database,
  id: string,
): Promise<{ name: string; pool: string }[]> {
  const files = await db
    .prepare('SELECT name, pool FROM files WHERE user_id = ?1')
    .bind(id)
    .all<{ name: string; pool: string }>();
  await db.batch([
    db.prepare('DELETE FROM usage WHERE user_id = ?1').bind(id),
    db.prepare('DELETE FROM tickets WHERE user_id = ?1').bind(id),
    db.prepare('DELETE FROM files WHERE user_id = ?1').bind(id),
    db.prepare('DELETE FROM purchases WHERE user_id = ?1').bind(id),
    db.prepare('DELETE FROM spend WHERE user_id = ?1').bind(id),
    db.prepare('DELETE FROM users WHERE id = ?1').bind(id),
  ]);
  return files.results;
}

// --- Spend -------------------------------------------------------------------

/** `YYYY-MM` in UTC: the month a subscriber's budget counts against. */
export function utcMonth(now: number): string {
  return new Date(now).toISOString().slice(0, 7);
}

/** What [id] has cost on the paid key this month, in micro-dollars. */
export async function spendThisMonth(db: D1Database, id: string, now: number): Promise<number> {
  const row = await db
    .prepare('SELECT micro_usd FROM spend WHERE user_id = ?1 AND month = ?2')
    .bind(id, utcMonth(now))
    .first<{ micro_usd: number }>();
  return row?.micro_usd ?? 0;
}

/** Adds one request's tokens (and, on the paid key, its cost) to the month. */
export async function recordSpend(
  db: D1Database,
  id: string,
  now: number,
  usage: { input: number; audioInput: number; output: number },
  microUsd: number,
  notes: number,
): Promise<void> {
  await db
    .prepare(
      `INSERT INTO spend (user_id, month, micro_usd, notes, input_tokens, output_tokens)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6)
       ON CONFLICT(user_id, month) DO UPDATE SET
         micro_usd = micro_usd + excluded.micro_usd,
         notes = notes + excluded.notes,
         input_tokens = input_tokens + excluded.input_tokens,
         output_tokens = output_tokens + excluded.output_tokens`,
    )
    .bind(id, utcMonth(now), microUsd, notes, usage.input + usage.audioInput, usage.output)
    .run();
}

/** The numbers the owner looks at (GET /v1/admin/stats). */
export async function stats(
  db: D1Database,
  now: number,
  budgetMicroUsd: number,
): Promise<Record<string, unknown>> {
  const day = new Date(now).toISOString().slice(0, 10);
  const month = utcMonth(now);
  const [today, monthNotes, monthSpend, users, plus, overBudget, exhausted] = await db.batch<
    Record<string, number | string | null>
  >([
    db
      .prepare(
        'SELECT COALESCE(SUM(notes), 0) AS notes, COUNT(*) AS active FROM usage WHERE day = ?1 AND notes > 0',
      )
      .bind(day),
    db
      .prepare(
        "SELECT COALESCE(SUM(notes), 0) AS notes, COUNT(*) AS active FROM usage WHERE day LIKE ?1 || '%' AND notes > 0",
      )
      .bind(month),
    db
      .prepare(
        `SELECT COALESCE(SUM(micro_usd), 0) AS micro, COALESCE(SUM(input_tokens), 0) AS input,
                COALESCE(SUM(output_tokens), 0) AS output FROM spend WHERE month = ?1`,
      )
      .bind(month),
    db.prepare('SELECT COUNT(*) AS n FROM users'),
    db.prepare('SELECT COUNT(*) AS n FROM users WHERE plus_until > ?1').bind(now),
    db
      .prepare('SELECT COUNT(*) AS n FROM spend WHERE month = ?1 AND micro_usd >= ?2')
      .bind(month, budgetMicroUsd),
    db.prepare("SELECT value FROM shared_state WHERE key = 'free_exhausted_until'"),
  ]);
  const first = (r: D1Result<Record<string, number | string | null>> | undefined) =>
    r?.results[0] ?? {};
  const exhaustedUntil = Number(first(exhausted).value ?? 0);
  return {
    today: { day, notes: first(today).notes, activeUsers: first(today).active },
    month: {
      month,
      notes: first(monthNotes).notes,
      activeUsers: first(monthNotes).active,
      paidKeySpendUsd: Number(first(monthSpend).micro ?? 0) / 1_000_000,
      inputTokens: first(monthSpend).input,
      outputTokens: first(monthSpend).output,
      plusOverBudget: first(overBudget).n,
    },
    users: first(users).n,
    plusUsers: first(plus).n,
    freeKeyUsedUpUntil: exhaustedUntil > now ? new Date(exhaustedUntil).toISOString() : null,
  };
}
