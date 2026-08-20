import { base32Decode, base32Encode } from './base32.util';
import {
  buildOtpauthUri,
  generateTotp,
  generateTotpSecret,
  verifyTotp,
} from './totp.util';

describe('base32', () => {
  it('round-trips arbitrary bytes', () => {
    const original = Buffer.from('The quick brown fox');
    expect(base32Decode(base32Encode(original)).equals(original)).toBe(true);
  });

  it('matches known RFC 4648 vectors', () => {
    expect(base32Encode(Buffer.from('foobar'))).toBe('MZXW6YTBOI');
    expect(base32Encode(Buffer.from('f'))).toBe('MY');
    expect(base32Encode(Buffer.from('fo'))).toBe('MZXQ');
  });

  it('tolerates lower case, padding, and whitespace on decode', () => {
    expect(base32Decode('mzxw6ytboi').toString()).toBe('foobar');
    expect(base32Decode('MZXW6YTBOI======').toString()).toBe('foobar');
    expect(base32Decode('MZXW 6YTB OI').toString()).toBe('foobar');
  });
});

describe('TOTP (RFC 6238 Appendix B vectors)', () => {
  // The RFC's SHA1 test key is the ASCII string "12345678901234567890".
  const secret = base32Encode(Buffer.from('12345678901234567890'));

  // (unix time, expected 8-digit code) straight from the RFC table.
  const vectors: Array<[number, string]> = [
    [59, '94287082'],
    [1111111109, '07081804'],
    [1111111111, '14050471'],
    [1234567890, '89005924'],
    [2000000000, '69279037'],
    [20000000000, '65353130'],
  ];

  it.each(vectors)('generates the RFC code at t=%i', (time, expected) => {
    expect(generateTotp(secret, { time, digits: 8 })).toBe(expected);
  });

  it.each(vectors)('verifies the RFC code at t=%i', (time, expected) => {
    expect(verifyTotp(secret, expected, { time, digits: 8, window: 0 })).toBe(true);
  });
});

describe('TOTP verification behaviour', () => {
  const secret = generateTotpSecret();

  it('accepts the current code', () => {
    const now = 1_700_000_000;
    const code = generateTotp(secret, { time: now });
    expect(verifyTotp(secret, code, { time: now })).toBe(true);
  });

  it('accepts a code from the previous step within the window (clock skew)', () => {
    const now = 1_700_000_000;
    const prev = generateTotp(secret, { time: now - 30 });
    expect(verifyTotp(secret, prev, { time: now, window: 1 })).toBe(true);
  });

  it('rejects a code outside the window', () => {
    const now = 1_700_000_000;
    const stale = generateTotp(secret, { time: now - 300 });
    expect(verifyTotp(secret, stale, { time: now, window: 1 })).toBe(false);
  });

  it('rejects a code for a different secret', () => {
    const now = 1_700_000_000;
    const code = generateTotp(generateTotpSecret(), { time: now });
    expect(verifyTotp(secret, code, { time: now })).toBe(false);
  });

  it('rejects malformed input without throwing', () => {
    expect(verifyTotp(secret, 'abcdef')).toBe(false);
    expect(verifyTotp(secret, '12345')).toBe(false); // wrong length
    expect(verifyTotp(secret, '')).toBe(false);
    expect(verifyTotp('not-valid-base32-!!!', '123456')).toBe(false);
  });

  it('tolerates spaces in the entered code', () => {
    const now = 1_700_000_000;
    const code = generateTotp(secret, { time: now });
    const spaced = `${code.slice(0, 3)} ${code.slice(3)}`;
    expect(verifyTotp(secret, spaced, { time: now })).toBe(true);
  });
});

describe('generateTotpSecret / buildOtpauthUri', () => {
  it('produces a decodable base32 secret', () => {
    const secret = generateTotpSecret();
    expect(() => base32Decode(secret)).not.toThrow();
    expect(secret).toMatch(/^[A-Z2-7]+$/);
  });

  it('builds a scannable otpauth URI with issuer and account', () => {
    const uri = buildOtpauthUri({
      secret: 'ABCDEF',
      accountName: 'jane@example.com',
      issuer: 'SocialHub',
    });
    expect(uri).toContain('otpauth://totp/');
    expect(uri).toContain('secret=ABCDEF');
    expect(uri).toContain('issuer=SocialHub');
    expect(uri).toContain(encodeURIComponent('SocialHub:jane@example.com'));
  });
});
