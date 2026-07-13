import { ConfigService } from '@nestjs/config';

import { TokenEncryptionService } from './token-encryption.service';

function makeService(keyHex: string): TokenEncryptionService {
  const configService = {
    getOrThrow: jest.fn().mockReturnValue(keyHex),
  } as unknown as ConfigService;
  return new TokenEncryptionService(configService);
}

// Generated via `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`.
// Length-asserted below rather than trusted by eye.
const VALID_TEST_KEY = '7afe82243b434261e7e05ff75afcdabf33dfa8bbd5a1d3cf7617efcffd6c5b6c';
const DIFFERENT_TEST_KEY = '7f5ebaa4b3ee9b81c42a4bb670594993a1e031e1ce39849068e0f01b58eb7da9';

describe('TokenEncryptionService', () => {
  it('test fixtures are exactly 64 hex chars (sanity check on the fixtures themselves)', () => {
    expect(VALID_TEST_KEY).toHaveLength(64);
    expect(DIFFERENT_TEST_KEY).toHaveLength(64);
    expect(VALID_TEST_KEY).not.toBe(DIFFERENT_TEST_KEY);
  });

  it('decrypts back to the exact original plaintext (round trip)', () => {
    const service = makeService(VALID_TEST_KEY);
    const plaintext = 'IGQVJYbG9uZ19hY2Nlc3NfdG9rZW5fZXhhbXBsZQ==';

    const encrypted = service.encrypt(plaintext);
    const decrypted = service.decrypt(encrypted);

    expect(decrypted).toBe(plaintext);
  });

  it('round-trips correctly for empty strings and unicode content', () => {
    const service = makeService(VALID_TEST_KEY);

    for (const plaintext of ['', '\ud83d\udd12 token with emoji', 'a'.repeat(5000)]) {
      expect(service.decrypt(service.encrypt(plaintext))).toBe(plaintext);
    }
  });

  it('produces different ciphertext for the same plaintext on each call (random IV)', () => {
    const service = makeService(VALID_TEST_KEY);
    const plaintext = 'same-input-every-time';

    const first = service.encrypt(plaintext);
    const second = service.encrypt(plaintext);

    expect(first).not.toBe(second);
    expect(service.decrypt(first)).toBe(plaintext);
    expect(service.decrypt(second)).toBe(plaintext);
  });

  it('fails closed (throws) if the ciphertext has been tampered with', () => {
    const service = makeService(VALID_TEST_KEY);
    const encrypted = service.encrypt('sensitive-value');

    const raw = Buffer.from(encrypted, 'base64');
    raw[raw.length - 1] ^= 0xff;
    const tampered = raw.toString('base64');

    expect(() => service.decrypt(tampered)).toThrow();
  });

  it('fails closed (throws) when decrypting with the wrong key', () => {
    const serviceA = makeService(VALID_TEST_KEY);
    const serviceB = makeService(DIFFERENT_TEST_KEY);

    const encrypted = serviceA.encrypt('secret');

    expect(() => serviceB.decrypt(encrypted)).toThrow();
  });

  it('rejects a key that is not exactly 32 bytes at construction time', () => {
    expect(() => makeService('tooshort')).toThrow(/32 bytes/);
  });
});
