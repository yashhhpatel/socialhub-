import { createHmac, randomBytes, timingSafeEqual } from 'crypto';

import { base32Decode, base32Encode } from './base32.util';

/**
 * RFC 6238 TOTP (time-based one-time passwords), the algorithm every
 * authenticator app — Google Authenticator, Authy, 1Password — implements.
 *
 * Deliberately hand-rolled on Node's `crypto` rather than adding otplib/
 * speakeasy: TOTP is a small, fully-specified standard (HMAC over a time
 * counter + dynamic truncation), a new backend dependency forces a
 * cross-platform lockfile regeneration on CI, and — most importantly —
 * correctness here is verifiable. totp.util.spec.ts checks this against the
 * official RFC 6238 Appendix B test vectors, so "we implemented it ourselves"
 * carries proof, not just assertion.
 *
 * SHA1 is the algorithm authenticator apps default to for TOTP; its use here
 * is HMAC (keyed), where SHA1 remains sound — this is not SHA1-as-a-hash.
 */

const DEFAULT_STEP_SECONDS = 30;
const DEFAULT_DIGITS = 6;
// Accept the immediately-adjacent windows too, so a code entered right as the
// step rolls over — or with mild client/server clock skew — still validates.
const DEFAULT_WINDOW = 1;
const SECRET_BYTES = 20; // 160-bit, the RFC-recommended SHA1 key size

/** A fresh random TOTP secret, base32-encoded for display / otpauth URIs. */
export function generateTotpSecret(): string {
  return base32Encode(randomBytes(SECRET_BYTES));
}

/**
 * The TOTP code for a base32 secret at a given time. `time` is unix seconds
 * (defaults to now); exposed mainly so tests can pin it to the RFC vectors.
 */
export function generateTotp(
  secretBase32: string,
  options: { time?: number; step?: number; digits?: number } = {},
): string {
  const step = options.step ?? DEFAULT_STEP_SECONDS;
  const digits = options.digits ?? DEFAULT_DIGITS;
  const time = options.time ?? Math.floor(Date.now() / 1000);
  const counter = Math.floor(time / step);

  return hotp(base32Decode(secretBase32), counter, digits);
}

/**
 * Constant-time-ish verification of a user-supplied code against the secret,
 * checking `window` steps either side of now. Returns false for a malformed
 * token rather than throwing, so a caller can treat "wrong" and "garbage"
 * alike.
 */
export function verifyTotp(
  secretBase32: string,
  token: string,
  options: { time?: number; step?: number; digits?: number; window?: number } = {},
): boolean {
  const step = options.step ?? DEFAULT_STEP_SECONDS;
  const digits = options.digits ?? DEFAULT_DIGITS;
  const window = options.window ?? DEFAULT_WINDOW;
  const time = options.time ?? Math.floor(Date.now() / 1000);

  const normalized = token.replace(/\s+/g, '');
  if (!/^\d+$/.test(normalized) || normalized.length !== digits) return false;

  let key: Buffer;
  try {
    key = base32Decode(secretBase32);
  } catch {
    return false;
  }

  const counter = Math.floor(time / step);
  for (let offset = -window; offset <= window; offset++) {
    const candidate = hotp(key, counter + offset, digits);
    if (constantTimeEquals(candidate, normalized)) return true;
  }
  return false;
}

/** The otpauth:// URI an authenticator app scans from a QR code. */
export function buildOtpauthUri(params: {
  secret: string;
  accountName: string;
  issuer: string;
}): string {
  const label = encodeURIComponent(`${params.issuer}:${params.accountName}`);
  const query = new URLSearchParams({
    secret: params.secret,
    issuer: params.issuer,
    algorithm: 'SHA1',
    digits: String(DEFAULT_DIGITS),
    period: String(DEFAULT_STEP_SECONDS),
  });
  return `otpauth://totp/${label}?${query.toString()}`;
}

/** RFC 4226 HOTP: HMAC-SHA1(counter) with dynamic truncation to N digits. */
function hotp(key: Buffer, counter: number, digits: number): string {
  // 8-byte big-endian counter. BigInt keeps it exact past 2^32.
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeBigUInt64BE(BigInt(counter));

  const hmac = createHmac('sha1', key).update(counterBuffer).digest();

  // Dynamic truncation (RFC 4226 §5.3): low 4 bits of the last byte pick the
  // offset of a 4-byte slice; mask off the sign bit.
  const offset = hmac[hmac.length - 1] & 0x0f;
  const binary =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);

  return (binary % 10 ** digits).toString().padStart(digits, '0');
}

function constantTimeEquals(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}
