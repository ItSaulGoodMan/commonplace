import { ApiError, logError } from './http';
import { b64url, pemToDer, utf8 } from './crypto';
import type { Deps } from './deps';

/** What Google Play says a subscription purchase gives access to. */
export interface PlayEntitlement {
  productId: string;
  /** Access ends at this time (ms). */
  expiresAt: number;
  /** Paid up (active, in grace period, or cancelled but not yet expired). */
  active: boolean;
  /** The account reference the app attached when buying, if any. */
  obfuscatedAccountId: string | null;
  testPurchase: boolean;
}

export interface PlayVerifier {
  verify(purchaseToken: string): Promise<PlayEntitlement>;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

const ACCESS_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  // Cancelled means "won't renew"; it still runs until expiryTime.
  'SUBSCRIPTION_STATE_CANCELED',
]);

/** Reads `purchases.subscriptionsv2` with a service account linked in Play Console. */
export class GooglePlayVerifier implements PlayVerifier {
  constructor(
    private readonly packageName: string,
    private readonly productIds: string[],
    private readonly serviceAccountJson: string,
    private readonly deps: Pick<Deps, 'fetch' | 'now'>,
  ) {}

  async verify(purchaseToken: string): Promise<PlayEntitlement> {
    const accessToken = await this.accessToken();
    const url =
      'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
      `${encodeURIComponent(this.packageName)}/purchases/subscriptionsv2/tokens/` +
      encodeURIComponent(purchaseToken);
    const response = await this.deps.fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (response.status === 404 || response.status === 410 || response.status === 400) {
      throw new ApiError('purchase_invalid', 'Google Play does not know this purchase.');
    }
    if (!response.ok) {
      logError('play_verify_failed', { status: response.status });
      throw new ApiError('busy', "Couldn't check the purchase with Google Play. Try again.", 30);
    }
    const body = (await response.json()) as {
      subscriptionState?: string;
      lineItems?: { productId?: string; expiryTime?: string }[];
      externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
      testPurchase?: unknown;
    };
    const items = (body.lineItems ?? []).filter(
      (i) => typeof i.productId === 'string' && this.productIds.includes(i.productId),
    );
    if (items.length === 0) {
      throw new ApiError('purchase_invalid', 'That purchase is not Commonplace Plus.');
    }
    let expiresAt = 0;
    let productId = items[0]!.productId!;
    for (const item of items) {
      const t = Date.parse(item.expiryTime ?? '');
      if (Number.isFinite(t) && t > expiresAt) {
        expiresAt = t;
        productId = item.productId!;
      }
    }
    return {
      productId,
      expiresAt,
      active: ACCESS_STATES.has(body.subscriptionState ?? '') && expiresAt > this.deps.now(),
      obfuscatedAccountId: body.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null,
      testPurchase: body.testPurchase !== undefined,
    };
  }

  /** OAuth access token for the Play Developer API, from a signed JWT. */
  private async accessToken(): Promise<string> {
    let account: ServiceAccount;
    try {
      account = JSON.parse(this.serviceAccountJson) as ServiceAccount;
    } catch {
      throw new ApiError('server', 'Purchases are not set up on the server yet.');
    }
    if (!account.client_email || !account.private_key) {
      throw new ApiError('server', 'Purchases are not set up on the server yet.');
    }
    const tokenUri = account.token_uri ?? 'https://oauth2.googleapis.com/token';
    const now = Math.floor(this.deps.now() / 1000);
    const header = b64url(utf8(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
    const claims = b64url(
      utf8(
        JSON.stringify({
          iss: account.client_email,
          scope: 'https://www.googleapis.com/auth/androidpublisher',
          aud: tokenUri,
          iat: now,
          exp: now + 3600,
        }),
      ),
    );
    const key = await crypto.subtle.importKey(
      'pkcs8',
      pemToDer(account.private_key),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      utf8(`${header}.${claims}`),
    );
    const response = await this.deps.fetch(tokenUri, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${header}.${claims}.${b64url(signature)}`,
      }),
    });
    if (!response.ok) {
      logError('play_token_failed', { status: response.status });
      throw new ApiError('busy', "Couldn't reach Google Play. Try again.", 30);
    }
    const { access_token } = (await response.json()) as { access_token?: string };
    if (!access_token) throw new ApiError('busy', "Couldn't reach Google Play. Try again.", 30);
    return access_token;
  }
}

/**
 * Local testing only (DEV_FAKES=1). `fake-<accountRef>-<anything>` is a paid-up
 * 30-day subscription bought by that account; anything else is unknown.
 */
export class FakePlayVerifier implements PlayVerifier {
  constructor(
    private readonly productIds: string[],
    private readonly deps: Pick<Deps, 'now'>,
  ) {}

  async verify(purchaseToken: string): Promise<PlayEntitlement> {
    const m = /^fake-([0-9a-f]{64})-/.exec(purchaseToken);
    if (!m) throw new ApiError('purchase_invalid', 'Google Play does not know this purchase.');
    return {
      productId: this.productIds[0] ?? 'commonplace_plus',
      expiresAt: this.deps.now() + 30 * 86_400_000,
      active: true,
      obfuscatedAccountId: m[1]!,
      testPurchase: true,
    };
  }
}
