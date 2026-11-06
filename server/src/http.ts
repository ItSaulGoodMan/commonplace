/** Errors the app understands, with the HTTP status each one travels with. */
export type ErrorCode =
  | 'signed_out'
  | 'daily_limit'
  | 'shared_limit'
  | 'busy'
  | 'blocked'
  | 'too_large'
  | 'bad_request'
  | 'not_found'
  | 'purchase_invalid'
  | 'server';

const statusFor: Record<ErrorCode, number> = {
  signed_out: 401,
  daily_limit: 429,
  shared_limit: 429,
  busy: 503,
  blocked: 422,
  too_large: 413,
  bad_request: 400,
  not_found: 404,
  purchase_invalid: 402,
  server: 500,
};

export class ApiError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly retryAfterSeconds?: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

export function errorResponse(error: ApiError): Response {
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (error.retryAfterSeconds !== undefined) {
    headers.set('Retry-After', String(Math.ceil(error.retryAfterSeconds)));
  }
  return new Response(
    JSON.stringify({
      error: {
        code: error.code,
        message: error.message,
        retryAfter: error.retryAfterSeconds,
      },
    }),
    { status: statusFor[error.code], headers },
  );
}

/** Reads a small JSON object body, refusing anything without a length or too big. */
export async function readJson(
  request: Request,
  maxBytes = 256 * 1024,
): Promise<Record<string, unknown>> {
  const length = Number(request.headers.get('Content-Length') ?? 'NaN');
  if (!Number.isFinite(length)) {
    throw new ApiError('bad_request', 'Content-Length is required.');
  }
  if (length > maxBytes) {
    throw new ApiError('too_large', 'That request is too large.');
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(await request.text());
  } catch {
    throw new ApiError('bad_request', 'The body is not valid JSON.');
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new ApiError('bad_request', 'The body must be a JSON object.');
  }
  return parsed as Record<string, unknown>;
}

export function log(event: string, fields: Record<string, unknown> = {}): void {
  console.log(JSON.stringify({ event, ...fields }));
}

export function logError(event: string, fields: Record<string, unknown> = {}): void {
  console.error(JSON.stringify({ event, ...fields }));
}
