import { createHmac, timingSafeEqual } from 'crypto';

/**
 * Verify a Meta Graph API webhook signature (`X-Hub-Signature-256`).
 *
 * Meta signs the EXACT raw request body with HMAC-SHA256 keyed on the app
 * secret and sends it as `X-Hub-Signature-256: sha256=<hex>`. We recompute it
 * over the same raw bytes and compare in constant time, so a forged event can't
 * move a customer's post/account state. Distinct from `signed_request`
 * (deauth/data-deletion) which is a dotted base64url token, not a header.
 *
 * Returns false on any missing/malformed input rather than throwing, so the
 * caller can map it to a single opaque 403.
 */
export function verifyMetaWebhookSignature(
  rawBody: string | Buffer | undefined,
  signatureHeader: string | undefined,
  appSecret: string | undefined | null,
): boolean {
  if (!rawBody || !signatureHeader || !appSecret) return false;
  if (!signatureHeader.startsWith('sha256=')) return false;

  const provided = signatureHeader.slice('sha256='.length).trim();
  const body = typeof rawBody === 'string' ? Buffer.from(rawBody, 'utf8') : rawBody;

  let providedBuf: Buffer;
  let expectedBuf: Buffer;
  try {
    providedBuf = Buffer.from(provided, 'hex');
    expectedBuf = createHmac('sha256', appSecret).update(body).digest();
  } catch {
    return false;
  }

  // timingSafeEqual throws on length mismatch — guard first (also catches a
  // non-hex / wrong-length signature that decoded to the wrong size).
  if (providedBuf.length !== expectedBuf.length) return false;
  return timingSafeEqual(providedBuf, expectedBuf);
}
