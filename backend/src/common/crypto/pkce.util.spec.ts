import { createHash } from 'crypto';

import { generatePkcePair } from './pkce.util';

describe('generatePkcePair', () => {
  it('generates a verifier within RFC 7636\'s 43-128 character range', () => {
    const { verifier } = generatePkcePair();
    expect(verifier.length).toBeGreaterThanOrEqual(43);
    expect(verifier.length).toBeLessThanOrEqual(128);
  });

  it('generates a verifier using only unreserved URL-safe characters', () => {
    const { verifier } = generatePkcePair();
    expect(verifier).toMatch(/^[A-Za-z0-9\-_]+$/);
  });

  it('challenge is the correct SHA-256(verifier), base64url-encoded (S256 method)', () => {
    const { verifier, challenge } = generatePkcePair();
    const expected = createHash('sha256').update(verifier).digest('base64url');
    expect(challenge).toBe(expected);
  });

  it('produces a different pair on every call', () => {
    const a = generatePkcePair();
    const b = generatePkcePair();
    expect(a.verifier).not.toBe(b.verifier);
    expect(a.challenge).not.toBe(b.challenge);
  });
});
