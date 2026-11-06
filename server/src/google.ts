import { ApiError } from './http';
import { decodeJsonSegment, fromB64url, utf8 } from './crypto';
import type { Deps } from './deps';

export interface GoogleUser {
  id: string;
  email: string;
  name: string | null;
}

const CERTS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const ISSUERS = new Set(['accounts.google.com', 'https://accounts.google.com']);
const CLOCK_SKEW_MS = 60_000;

interface Jwk extends JsonWebKey {
  kid?: string;
}

const signedOut = (why: string): ApiError =>
  new ApiError('signed_out', `Google sign-in didn't check out (${why}). Sign in again.`);

/**
 * Checks a Google ID token from the app's "Sign in with Google": signed by
 * Google, meant for this app, not expired, with a verified email.
 */
export async function verifyGoogleIdToken(
  token: string,
  clientIds: string[],
  deps: Pick<Deps, 'fetch' | 'now'>,
): Promise<GoogleUser> {
  const parts = token.split('.');
  if (parts.length !== 3) throw signedOut('malformed');
  const [headerPart, payloadPart, signaturePart] = parts as [string, string, string];

  let header: { alg?: unknown; kid?: unknown };
  let claims: Record<string, unknown>;
  try {
    header = decodeJsonSegment(headerPart) as typeof header;
    claims = decodeJsonSegment(payloadPart) as Record<string, unknown>;
  } catch {
    throw signedOut('unreadable');
  }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string') {
    throw signedOut('algorithm');
  }

  const response = await deps.fetch(CERTS_URL);
  if (!response.ok) throw new ApiError('busy', 'Google is not answering. Try again.', 30);
  const { keys } = (await response.json()) as { keys?: Jwk[] };
  const jwk = keys?.find((k) => k.kid === header.kid);
  if (!jwk) throw signedOut('unknown key');

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    fromB64url(signaturePart),
    utf8(`${headerPart}.${payloadPart}`),
  );
  if (!valid) throw signedOut('signature');

  if (typeof claims.iss !== 'string' || !ISSUERS.has(claims.iss)) {
    throw signedOut('issuer');
  }
  const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audiences.some((a) => typeof a === 'string' && clientIds.includes(a))) {
    throw signedOut('audience');
  }
  if (typeof claims.exp !== 'number' || claims.exp * 1000 + CLOCK_SKEW_MS < deps.now()) {
    throw signedOut('expired');
  }
  if (claims.email_verified !== true && claims.email_verified !== 'true') {
    throw signedOut('email not verified');
  }
  if (typeof claims.sub !== 'string' || typeof claims.email !== 'string') {
    throw signedOut('claims');
  }
  return {
    id: claims.sub,
    email: claims.email,
    name: typeof claims.name === 'string' ? claims.name : null,
  };
}

/**
 * Local testing only (DEV_FAKES=1): `dev:{"sub":"1","email":"a@b.c"}` stands in
 * for a Google token, like the Firebase Auth emulator's fake tokens.
 */
export function devUser(token: string): GoogleUser | null {
  if (!token.startsWith('dev:')) return null;
  try {
    const claims = JSON.parse(token.slice(4)) as Record<string, unknown>;
    if (typeof claims.sub !== 'string' || typeof claims.email !== 'string') return null;
    return {
      id: `dev-${claims.sub}`,
      email: claims.email,
      name: typeof claims.name === 'string' ? claims.name : null,
    };
  } catch {
    return null;
  }
}
