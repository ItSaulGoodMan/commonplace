import prompts from './prompts.json';
import {
  type Account,
  accountRef,
  accountView,
  charge,
  type Counter,
  createTicket,
  deleteAccountData,
  findUser,
  getShared,
  hasTicket,
  isPlus,
  limitsFrom,
  notesPerDay,
  recordSpend,
  refund,
  setPlus,
  setShared,
  spendThisMonth,
  stats,
  upsertUser,
  usageToday,
  useTicket,
} from './accounts';
import { sha256Hex, utf8 } from './crypto';
import type { Deps } from './deps';
import { type GenerateOptions, Gemini, type Pool, SharedLimitError } from './gemini';
import { devUser, type GoogleUser, verifyGoogleIdToken } from './google';
import { ApiError, json, log, readJson } from './http';
import { FakePlayVerifier, GooglePlayVerifier, type PlayVerifier } from './play';
import { readSession, createSession } from './session';
import { costMicroUsd, type Prices, type TokenUsage, videoPlan } from './strategy';
import { nextPacificMidnight, nextUtcMidnight } from './time';

/** Workers on a free-plan domain accept bodies up to 100 MB. */
const MAX_UPLOAD_BYTES = 95 * 1024 * 1024;
const MAX_FILES_PER_NOTE = 10;
const MAX_MATERIAL_CHARS = 60_000;
/** Polls of Gemini's file state per extract, across all of a note's videos. */
const POLL_BUDGET = 25;
const RECHECK_PLUS_MS = 3_600_000;
const FREE_EXHAUSTED_KEY = 'free_exhausted_until';
/** Caps what one runaway answer can cost (a transcript and a note fit easily). */
const MAX_OUTPUT_READ = 8192;
const MAX_OUTPUT_WRITE = 2048;
const MAX_CAPTION_CHARS = 5_000;

const AUTHED_ROUTES = new Set([
  'GET /v1/me',
  'DELETE /v1/me',
  'POST /v1/files',
  'POST /v1/note',
  'POST /v1/extract',
  'POST /v1/write',
  'POST /v1/plus',
]);

export async function handle(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  deps: Deps,
): Promise<Response> {
  const url = new URL(request.url);
  const route = `${request.method} ${url.pathname}`;
  if (route === 'GET /') return json({ service: 'commonplace-api', ok: true });
  if (route === 'POST /v1/session') return session(request, env, deps);
  if (route === 'GET /v1/admin/stats') return adminStats(request, env, deps);
  if (!AUTHED_ROUTES.has(route)) throw new ApiError('not_found', 'No such endpoint.');

  let account = await authenticate(request, env, deps);
  account = await refreshPlus(env, account, deps);
  switch (route) {
    case 'GET /v1/me':
      return json({ account: await view(env, account, deps) });
    case 'DELETE /v1/me':
      return deleteMe(env, ctx, account, deps);
    case 'POST /v1/files':
      return upload(request, env, account, deps);
    case 'POST /v1/note':
      return note(request, env, ctx, account, deps);
    case 'POST /v1/extract':
      return extract(request, env, ctx, account, deps);
    case 'POST /v1/write':
      return write(request, env, account, deps);
    default:
      return plus(request, env, account, deps);
  }
}

// --- Sign-in -----------------------------------------------------------------

async function session(request: Request, env: Env, deps: Deps): Promise<Response> {
  const body = await readJson(request, 16 * 1024);
  const idToken = body.idToken;
  if (typeof idToken !== 'string' || idToken.length === 0) {
    throw new ApiError('bad_request', 'idToken is required.');
  }
  let user: GoogleUser | null = env.DEV_FAKES === '1' ? devUser(idToken) : null;
  if (!user) {
    const clientIds = env.GOOGLE_CLIENT_IDS.split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    if (clientIds.length === 0) throw new ApiError('server', 'Sign-in is not set up yet.');
    user = await verifyGoogleIdToken(idToken, clientIds, deps);
  }
  const now = deps.now();
  await upsertUser(env.DB, user, now);
  const account = await findUser(env.DB, user.id);
  if (!account) throw new ApiError('server', 'Could not create the account.');
  log('signed_in', { user: await accountRef(user.id) });
  return json({
    session: await createSession(env.SESSION_SECRET, user.id, now),
    account: await view(env, account, deps),
  });
}

async function authenticate(request: Request, env: Env, deps: Deps): Promise<Account> {
  const header = request.headers.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  const id = token ? await readSession(env.SESSION_SECRET, token, deps.now()) : null;
  const account = id ? await findUser(env.DB, id) : null;
  if (!account) throw new ApiError('signed_out', 'Sign in with Google to continue.');
  return account;
}

function view(env: Env, account: Account, deps: Deps): Promise<Record<string, unknown>> {
  return accountView(env.DB, account, limitsFrom(env), deps.now());
}

// --- Notes -------------------------------------------------------------------

function budgetMicroUsd(env: Env): number {
  const usd = Number.parseFloat(env.PLUS_MONTHLY_BUDGET_USD);
  return Number.isFinite(usd) && usd >= 0 ? Math.round(usd * 1_000_000) : 1_000_000;
}

function paidPrices(env: Env): Prices {
  const n = (v: string, fallback: number): number => {
    const parsed = Number.parseFloat(v);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
  };
  return {
    input: n(env.PAID_PRICE_INPUT_PER_M, 0.3),
    audioInput: n(env.PAID_PRICE_AUDIO_PER_M, 0.3),
    output: n(env.PAID_PRICE_OUTPUT_PER_M, 2.5),
  };
}

/**
 * Who pays for this account's next request. Free accounts always use the
 * free key, so they can never cost money. Subscribers use the paid key until
 * this month's measured spend reaches the budget, then the free key: a
 * subscriber never costs more than the budget (plus at most one note).
 */
async function poolFor(env: Env, account: Account, deps: Deps): Promise<Pool> {
  const now = deps.now();
  if (!isPlus(account, now) || !env.GEMINI_PAID_API_KEY) return 'free';
  const spent = await spendThisMonth(env.DB, account.id, now);
  return spent < budgetMicroUsd(env) ? 'paid' : 'free';
}

function generateOptions(env: Env, pool: Pool, maxOutputTokens: number): GenerateOptions {
  return {
    thinkingLevel: (pool === 'paid' ? env.GEMINI_PAID_THINKING : env.GEMINI_THINKING).trim(),
    maxOutputTokens,
  };
}

/** Books one request's tokens; on the paid key, its cost too. */
async function meter(
  env: Env,
  account: Account,
  pool: Pool,
  usage: TokenUsage,
  notes: number,
  deps: Deps,
): Promise<void> {
  const micro = pool === 'paid' ? costMicroUsd(usage, paidPrices(env)) : 0;
  await recordSpend(env.DB, account.id, deps.now(), usage, micro, notes);
}

function gemini(env: Env, pool: Pool, deps: Deps): Gemini {
  return pool === 'paid'
    ? new Gemini(env.GEMINI_BASE_URL, env.GEMINI_PAID_API_KEY, env.GEMINI_PAID_MODEL, deps)
    : new Gemini(env.GEMINI_BASE_URL, env.GEMINI_API_KEY, env.GEMINI_MODEL, deps);
}

/** When the free key ran out today, don't even try until it resets. */
async function ensureSharedOpen(env: Env, pool: Pool, deps: Deps): Promise<void> {
  if (pool !== 'free') return;
  const until = Number((await getShared(env.DB, FREE_EXHAUSTED_KEY)) ?? 0);
  const now = deps.now();
  if (until > now) {
    const error = new SharedLimitError(until);
    throw new ApiError(error.code, error.message, (until - now) / 1000);
  }
}

async function onFailure(env: Env, pool: Pool, error: unknown, deps: Deps): Promise<never> {
  if (error instanceof SharedLimitError && pool === 'free') {
    const until = nextPacificMidnight(deps.now());
    await setShared(env.DB, FREE_EXHAUSTED_KEY, String(until));
    log('free_key_exhausted', { until });
    throw new ApiError(error.code, error.message, (until - deps.now()) / 1000);
  }
  throw error;
}

function dailyLimit(account: Account, env: Env, now: number): ApiError {
  const limits = limitsFrom(env);
  const perDay = notesPerDay(account, limits, now);
  const more = isPlus(account, now)
    ? ''
    : ` With Commonplace Plus you can make ${limits.plusNotesPerDay} a day.`;
  return new ApiError(
    'daily_limit',
    `You've made today's ${perDay} notes. The rest are made tomorrow.${more}`,
    (nextUtcMidnight(now) - now) / 1000,
  );
}

async function upload(
  request: Request,
  env: Env,
  account: Account,
  deps: Deps,
): Promise<Response> {
  const mimeType = (request.headers.get('Content-Type') ?? '').split(';')[0]!.trim().toLowerCase();
  if (!/^(video|image)\/[\w.+-]+$/.test(mimeType)) {
    throw new ApiError('bad_request', 'Only videos and images can be uploaded.');
  }
  const size = Number(request.headers.get('Content-Length'));
  if (!Number.isInteger(size) || size <= 0 || !request.body) {
    throw new ApiError('bad_request', 'Content-Length is required.');
  }
  if (size > MAX_UPLOAD_BYTES) {
    throw new ApiError('too_large', 'This file is too large. Try a shorter clip.');
  }
  const now = deps.now();
  const limits = limitsFrom(env);
  const used = await usageToday(env.DB, account.id, now);
  if (used.notes >= notesPerDay(account, limits, now)) throw dailyLimit(account, env, now);

  const pool = await poolFor(env, account, deps);
  await ensureSharedOpen(env, pool, deps);
  if (!(await charge(env.DB, account.id, 'uploads', limits.uploadsPerDay, now))) {
    throw new ApiError('daily_limit', "That's a lot of uploads for one day. Try again tomorrow.");
  }
  const displayName = (request.headers.get('X-File-Name') ?? 'reel')
    .replace(/[^\w. -]/g, '')
    .slice(0, 60) || 'reel';
  try {
    const file = await gemini(env, pool, deps).upload(request.body, size, mimeType, displayName);
    await env.DB.batch([
      env.DB.prepare(
        'INSERT INTO files (name, user_id, mime_type, uri, pool, created_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6)',
      ).bind(file.name, account.id, file.mimeType, file.uri, pool, now),
      // Gemini deletes files after 48 hours anyway; forget stale ones too.
      env.DB.prepare('DELETE FROM files WHERE created_at < ?1').bind(now - 2 * 86_400_000),
    ]);
    return json({ file: { name: file.name } });
  } catch (e) {
    await refund(env.DB, account.id, 'uploads', now);
    return onFailure(env, pool, e, deps);
  }
}

interface FileRow {
  name: string;
  mime_type: string;
  uri: string;
  pool: Pool;
}

interface NoteFiles {
  pool: Pool;
  /** In the order the app sent them (a carousel reads left to right). */
  ordered: FileRow[];
  /** Deletes them from Gemini and forgets them. */
  cleanup(): Promise<void>;
}

async function loadFiles(
  names: unknown,
  env: Env,
  account: Account,
  deps: Deps,
): Promise<NoteFiles> {
  if (
    !Array.isArray(names) ||
    names.length === 0 ||
    names.length > MAX_FILES_PER_NOTE ||
    !names.every((n) => typeof n === 'string' && /^files\/[\w-]+$/.test(n))
  ) {
    throw new ApiError('bad_request', `Send 1 to ${MAX_FILES_PER_NOTE} uploaded file names.`);
  }
  const placeholders = names.map((_, i) => `?${i + 2}`).join(', ');
  const { results: rows } = await env.DB.prepare(
    `SELECT name, mime_type, uri, pool FROM files WHERE user_id = ?1 AND name IN (${placeholders})`,
  )
    .bind(account.id, ...names)
    .all<FileRow>();
  if (rows.length !== new Set(names).size) {
    throw new ApiError('not_found', 'Those files are gone. Upload them again.');
  }
  const pool = rows[0]!.pool;
  if (rows.some((r) => r.pool !== pool)) {
    throw new ApiError('bad_request', 'Upload the files of one note together.');
  }
  const ordered = (names as string[]).map((n) => rows.find((r) => r.name === n)!);
  const g = gemini(env, pool, deps);
  return {
    pool,
    ordered,
    cleanup: async () => {
      for (const row of ordered) await g.deleteFile(row.name);
      await env.DB.prepare(`DELETE FROM files WHERE user_id = ?1 AND name IN (${placeholders})`)
        .bind(account.id, ...names)
        .run();
    },
  };
}

/**
 * The media parts of a request, each video with its watching plan. Waits
 * for Gemini to finish processing videos first.
 */
async function mediaParts(g: Gemini, ordered: FileRow[]): Promise<Record<string, unknown>[]> {
  let budget = POLL_BUDGET;
  const parts: Record<string, unknown>[] = [];
  for (const row of ordered) {
    const part: Record<string, unknown> = {
      fileData: { mimeType: row.mime_type, fileUri: row.uri },
    };
    if (row.mime_type.startsWith('video/')) {
      const { polls, durationSeconds } = await g.waitUntilActive(row.name, Math.max(1, budget));
      budget -= polls;
      const plan = videoPlan(durationSeconds);
      // One frame a second is Gemini's default; only say something else.
      if (plan.fps !== 1 || plan.endOffset) {
        part.videoMetadata = {
          fps: plan.fps,
          ...(plan.endOffset ? { endOffset: plan.endOffset } : {}),
        };
      }
    }
    parts.push(part);
  }
  return parts;
}

/**
 * One request per note: Gemini watches once and returns what it read and
 * the note. Counts as one note.
 */
async function note(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  account: Account,
  deps: Deps,
): Promise<Response> {
  const body = await readJson(request);
  const { caption, language } = body;
  if (caption !== undefined && caption !== null && typeof caption !== 'string') {
    throw new ApiError('bad_request', 'caption must be text.');
  }
  if (typeof caption === 'string' && caption.length > MAX_CAPTION_CHARS) {
    throw new ApiError('too_large', 'That caption is too long.');
  }
  checkLanguage(language);
  const { pool, ordered, cleanup } = await loadFiles(body.files, env, account, deps);
  const now = deps.now();
  try {
    await ensureSharedOpen(env, pool, deps);
  } catch (e) {
    ctx.waitUntil(cleanup());
    throw e;
  }
  if (!(await charge(env.DB, account.id, 'notes', notesPerDay(account, limitsFrom(env), now), now))) {
    ctx.waitUntil(cleanup());
    throw dailyLimit(account, env, now);
  }
  const g = gemini(env, pool, deps);
  try {
    const lang = typeof language === 'string' ? language : prompts.readSameLanguage;
    const text =
      prompts.read.replace('{language}', () => lang) +
      (typeof caption === 'string' && caption.trim()
        ? prompts.readCaption.replace('{caption}', () => caption.trim())
        : '');
    const { json: answer, usage } = await g.generateJson(
      [...(await mediaParts(g, ordered)), { text }],
      prompts.readSchema,
      generateOptions(env, pool, MAX_OUTPUT_READ),
    );
    await meter(env, account, pool, usage, 1, deps);
    const extraction: Record<string, unknown> = {};
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(answer)) {
      (key in prompts.extractSchema.properties ? extraction : result)[key] = value;
    }
    log('note_made', { pool, files: ordered.length, ...usage });
    return json({ extraction, note: result });
  } catch (e) {
    await refund(env.DB, account.id, 'notes', now);
    return onFailure(env, pool, e, deps);
  } finally {
    // Gemini keeps nothing longer than needed to read it.
    ctx.waitUntil(cleanup());
  }
}

function checkLanguage(language: unknown): void {
  if (
    language !== undefined &&
    language !== null &&
    (typeof language !== 'string' || !/^[\p{L} ]{2,40}$/u.test(language))
  ) {
    throw new ApiError('bad_request', 'Unknown note language.');
  }
}

/** The read-only half of [note]; kept for apps that still call it. */
async function extract(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  account: Account,
  deps: Deps,
): Promise<Response> {
  const body = await readJson(request);
  const { pool, ordered, cleanup } = await loadFiles(body.files, env, account, deps);
  const now = deps.now();
  const g = gemini(env, pool, deps);

  try {
    await ensureSharedOpen(env, pool, deps);
  } catch (e) {
    ctx.waitUntil(cleanup());
    throw e;
  }
  if (!(await charge(env.DB, account.id, 'notes', notesPerDay(account, limitsFrom(env), now), now))) {
    ctx.waitUntil(cleanup());
    throw dailyLimit(account, env, now);
  }
  try {
    const { json: extraction, usage } = await g.generateJson(
      [...(await mediaParts(g, ordered)), { text: prompts.extract }],
      prompts.extractSchema,
      generateOptions(env, pool, MAX_OUTPUT_READ),
    );
    await meter(env, account, pool, usage, 1, deps);
    const ticket = await createTicket(env.DB, account.id, now);
    log('extracted', { pool, files: ordered.length });
    return json({ extraction, ticket });
  } catch (e) {
    await refund(env.DB, account.id, 'notes', now);
    return onFailure(env, pool, e, deps);
  } finally {
    // Gemini keeps nothing longer than needed to read it.
    ctx.waitUntil(cleanup());
  }
}

async function write(
  request: Request,
  env: Env,
  account: Account,
  deps: Deps,
): Promise<Response> {
  const body = await readJson(request);
  const { material, language, ticket, rewrite } = body;
  if (typeof material !== 'string' || material.trim().length === 0) {
    throw new ApiError('bad_request', 'There is nothing to write a note from.');
  }
  if (material.length > MAX_MATERIAL_CHARS) {
    throw new ApiError('too_large', 'This one has too much text for a note.');
  }
  checkLanguage(language);
  const now = deps.now();
  const limits = limitsFrom(env);
  const pool = await poolFor(env, account, deps);
  await ensureSharedOpen(env, pool, deps);

  let charged: Counter | null = null;
  const prepaid =
    typeof ticket === 'string' && (await hasTicket(env.DB, account.id, ticket, now));
  if (!prepaid) {
    if (rewrite === true) {
      if (!(await charge(env.DB, account.id, 'rewrites', limits.rewritesPerDay, now))) {
        throw new ApiError(
          'daily_limit',
          "You've rewritten a lot of notes today. Try again tomorrow.",
          (nextUtcMidnight(now) - now) / 1000,
        );
      }
      charged = 'rewrites';
    } else {
      if (!(await charge(env.DB, account.id, 'notes', notesPerDay(account, limits, now), now))) {
        throw dailyLimit(account, env, now);
      }
      charged = 'notes';
    }
  }
  try {
    const lang = typeof language === 'string' ? language : prompts.distillSameLanguage;
    // Function replacers: `$&` and friends in the material stay literal.
    const prompt = prompts.distill
      .replace('{language}', () => lang)
      .replace('{material}', () => material);
    const { json: written, usage } = await gemini(env, pool, deps).generateJson(
      [{ text: prompt }],
      prompts.distillSchema,
      generateOptions(env, pool, MAX_OUTPUT_WRITE),
    );
    await meter(env, account, pool, usage, charged === 'notes' ? 1 : 0, deps);
    if (prepaid) await useTicket(env.DB, ticket as string, now);
    return json({ note: written });
  } catch (e) {
    if (charged) await refund(env.DB, account.id, charged, now);
    return onFailure(env, pool, e, deps);
  }
}

// --- Commonplace Plus --------------------------------------------------------

function verifier(env: Env, deps: Deps): PlayVerifier {
  const productIds = env.PLAY_PRODUCT_IDS.split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return env.DEV_FAKES === '1'
    ? new FakePlayVerifier(productIds, deps)
    : new GooglePlayVerifier(env.PLAY_PACKAGE_NAME, productIds, env.PLAY_SERVICE_ACCOUNT, deps);
}

async function plus(
  request: Request,
  env: Env,
  account: Account,
  deps: Deps,
): Promise<Response> {
  const body = await readJson(request, 16 * 1024);
  const { purchaseToken } = body;
  if (typeof purchaseToken !== 'string' || purchaseToken.length < 10) {
    throw new ApiError('bad_request', 'purchaseToken is required.');
  }
  const entitlement = await verifier(env, deps).verify(purchaseToken);
  const ref = await accountRef(account.id);
  const elsewhere = new ApiError(
    'purchase_invalid',
    'This purchase belongs to another Commonplace account.',
  );
  if (entitlement.obfuscatedAccountId && entitlement.obfuscatedAccountId !== ref) {
    throw elsewhere;
  }
  const tokenHash = await sha256Hex(purchaseToken);
  const owner = await env.DB.prepare('SELECT user_id FROM purchases WHERE token_hash = ?1')
    .bind(tokenHash)
    .first<{ user_id: string }>();
  if (owner && owner.user_id !== account.id) throw elsewhere;

  const now = deps.now();
  await env.DB.prepare('INSERT OR IGNORE INTO purchases (token_hash, user_id) VALUES (?1, ?2)')
    .bind(tokenHash, account.id)
    .run();
  await setPlus(env.DB, account.id, {
    until: entitlement.active ? entitlement.expiresAt : null,
    product: entitlement.productId,
    token: purchaseToken,
    checkedAt: now,
  });
  log('plus_verified', { user: ref, active: entitlement.active, test: entitlement.testPurchase });
  const updated = (await findUser(env.DB, account.id)) ?? account;
  return json({ account: await view(env, updated, deps) });
}

/** A lapsed subscription may have renewed: ask Play again, at most hourly. */
async function refreshPlus(env: Env, account: Account, deps: Deps): Promise<Account> {
  const now = deps.now();
  if (
    !account.plusToken ||
    isPlus(account, now) ||
    (account.plusCheckedAt !== null && now - account.plusCheckedAt < RECHECK_PLUS_MS)
  ) {
    return account;
  }
  try {
    const entitlement = await verifier(env, deps).verify(account.plusToken);
    const until = entitlement.active ? entitlement.expiresAt : null;
    await setPlus(env.DB, account.id, {
      until,
      product: entitlement.productId,
      token: account.plusToken,
      checkedAt: now,
    });
    return { ...account, plusUntil: until, plusCheckedAt: now };
  } catch (e) {
    if (e instanceof ApiError && e.code === 'purchase_invalid') {
      await setPlus(env.DB, account.id, {
        until: null,
        product: account.plusProduct ?? '',
        token: account.plusToken,
        checkedAt: now,
      });
      return { ...account, plusUntil: null, plusCheckedAt: now };
    }
    // Play unreachable: keep what we had and try again next time.
    return account;
  }
}

// --- Account deletion ----------------------------------------------------------

async function deleteMe(
  env: Env,
  ctx: ExecutionContext,
  account: Account,
  deps: Deps,
): Promise<Response> {
  const files = await deleteAccountData(env.DB, account.id);
  ctx.waitUntil(
    (async () => {
      for (const f of files) {
        const pool: Pool = f.pool === 'paid' ? 'paid' : 'free';
        await gemini(env, pool, deps).deleteFile(f.name);
      }
    })(),
  );
  log('account_deleted', { user: await accountRef(account.id) });
  return json({ deleted: true });
}

// --- For the owner ---------------------------------------------------------------

/**
 * Today's and this month's numbers, for whoever runs the server:
 * `curl -H "Authorization: Bearer $ADMIN_TOKEN" https://.../v1/admin/stats`.
 * Answers 404 unless ADMIN_TOKEN is set.
 */
async function adminStats(request: Request, env: Env, deps: Deps): Promise<Response> {
  const expected = env.ADMIN_TOKEN ?? '';
  const header = request.headers.get('Authorization') ?? '';
  const given = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (expected.length < 16 || !(await sameSecret(given, expected))) {
    throw new ApiError('not_found', 'No such endpoint.');
  }
  return json(await stats(env.DB, deps.now(), budgetMicroUsd(env)));
}

/** Constant-time comparison (of hashes, so lengths always match). */
async function sameSecret(a: string, b: string): Promise<boolean> {
  const [ha, hb] = await Promise.all([
    crypto.subtle.digest('SHA-256', utf8(a)),
    crypto.subtle.digest('SHA-256', utf8(b)),
  ]);
  return crypto.subtle.timingSafeEqual(ha, hb);
}
