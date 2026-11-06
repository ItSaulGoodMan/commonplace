import { ApiError } from './http';
import { b64url, decodeJsonSegment, fromB64url, utf8 } from './crypto';

/** How long the app stays signed in without asking Google again. */
export const SESSION_MS = 90 * 86_400_000;

async function hmacKey(secret: string): Promise<CryptoKey> {
  if (secret.length < 32) {
    throw new ApiError('server', 'The server is not set up yet.');
  }
  return crypto.subtle.importKey(
    'raw',
    utf8(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify'],
  );
}

/** A signed `payload.signature` token naming the Google account. */
export async function createSession(
  secret: string,
  userId: string,
  now: number,
): Promise<string> {
  const payload = b64url(utf8(JSON.stringify({ sub: userId, exp: now + SESSION_MS })));
  const signature = await crypto.subtle.sign('HMAC', await hmacKey(secret), utf8(payload));
  return `${payload}.${b64url(signature)}`;
}

/** The account id in a valid, unexpired session, or null. */
export async function readSession(
  secret: string,
  token: string,
  now: number,
): Promise<string | null> {
  const [payload, signature, extra] = token.split('.');
  if (!payload || !signature || extra !== undefined) return null;
  let valid = false;
  try {
    // crypto.subtle.verify compares in constant time.
    valid = await crypto.subtle.verify(
      'HMAC',
      await hmacKey(secret),
      fromB64url(signature),
      utf8(payload),
    );
  } catch (e) {
    if (e instanceof ApiError) throw e;
    return null;
  }
  if (!valid) return null;
  const claims = decodeJsonSegment(payload) as { sub?: unknown; exp?: unknown };
  if (typeof claims.sub !== 'string' || typeof claims.exp !== 'number') return null;
  return claims.exp > now ? claims.sub : null;
}
