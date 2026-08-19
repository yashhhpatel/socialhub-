import { createHmac, timingSafeEqual } from 'crypto';

/**
 * The claims Meta includes in the `signed_request` it POSTs to the app's
 * Deauthorize and Data Deletion callback URLs. `user_id` is the app-scoped
 * ID of the person who removed the app or requested deletion.
 *
 * See:
 * https://developers.facebook.com/docs/facebook-login/guides/advanced/data-deletion
 */
export interface MetaSignedRequestPayload {
  user_id: string;
  algorithm: string;
  issued_at?: number;
  [key: string]: unknown;
}

/**
 * Parse and verify a Meta `signed_request` (`<base64url signature>.<base64url payload>`).
 *
 * Meta signs the payload with HMAC-SHA256 keyed on the app secret. We recompute
 * the signature and compare in constant time — a request whose signature doesn't
 * verify against our own app secret is rejected, so a forged deletion/deauth
 * request can't wipe someone's data. Returns `null` on any malformed or
 * unverifiable input (the caller maps that to a 400).
 */
export function parseMetaSignedRequest(
  signedRequest: string | undefined,
  appSecret: string,
): MetaSignedRequestPayload | null {
  if (!signedRequest || !signedRequest.includes('.')) return null;

  const [encodedSig, encodedPayload] = signedRequest.split('.', 2);
  if (!encodedSig || !encodedPayload) return null;

  let expectedSig: Buffer;
  let providedSig: Buffer;
  let payload: MetaSignedRequestPayload;
  try {
    providedSig = base64UrlToBuffer(encodedSig);
    expectedSig = createHmac('sha256', appSecret)
      .update(encodedPayload)
      .digest();
    payload = JSON.parse(
      base64UrlToBuffer(encodedPayload).toString('utf8'),
    ) as MetaSignedRequestPayload;
  } catch {
    return null;
  }

  // Length check first — timingSafeEqual throws on unequal lengths.
  if (
    providedSig.length !== expectedSig.length ||
    !timingSafeEqual(providedSig, expectedSig)
  ) {
    return null;
  }

  if (
    typeof payload.algorithm !== 'string' ||
    payload.algorithm.toUpperCase() !== 'HMAC-SHA256' ||
    typeof payload.user_id !== 'string' ||
    payload.user_id.length === 0
  ) {
    return null;
  }

  return payload;
}

function base64UrlToBuffer(input: string): Buffer {
  const padded = input
    .replace(/-/g, '+')
    .replace(/_/g, '/')
    .padEnd(Math.ceil(input.length / 4) * 4, '=');
  return Buffer.from(padded, 'base64');
}
