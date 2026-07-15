import { createHash, randomBytes } from 'crypto';

export interface PkcePair {
  verifier: string;
  challenge: string;
}

/**
 * Generates a PKCE (RFC 7636) verifier/challenge pair, using the S256
 * challenge method (SHA-256 of the verifier, base64url-encoded) — the
 * secure, recommended method, not the weaker "plain" alternative some
 * providers still accept.
 *
 * First real caller is XAdapter (Milestone 2.3), but this is generic
 * OAuth crypto with no X-specific knowledge, so it lives in common/crypto
 * rather than inside social-accounts/ — any future platform needing PKCE
 * reuses this directly.
 */
export function generatePkcePair(): PkcePair {
  // 48 random bytes -> 64 base64url chars, within RFC 7636's required
  // 43-128 character range for a verifier.
  const verifier = randomBytes(48).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');

  return { verifier, challenge };
}
