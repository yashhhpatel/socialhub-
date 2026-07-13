import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createCipheriv,
  createDecipheriv,
  randomBytes,
} from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH_BYTES = 12; // 96-bit IV — the size GCM is designed for
const AUTH_TAG_LENGTH_BYTES = 16;
const KEY_LENGTH_BYTES = 32; // AES-256

/**
 * Encrypts/decrypts sensitive strings (OAuth access/refresh tokens) at
 * application level, per docs/architecture/SocialHub_Architecture_Plan.md
 * §7 ("token encryption service (KMS or app-level AES)"). App-level AES
 * chosen over KMS for now — no cloud KMS infrastructure exists yet at
 * this stage of the build; this can be swapped for a KMS-backed
 * implementation later without changing this class's public interface
 * (encrypt/decrypt take and return plain strings either way).
 *
 * Output packs iv + authTag + ciphertext into a single base64 string, so
 * a DB column only ever needs to store one opaque value — see
 * SocialAccount.accessTokenEnc/refreshTokenEnc in the database design doc.
 *
 * SCOPE NOTE: this milestone's file list is "Files/folders modified:
 * none" — TOKEN_ENCRYPTION_KEY is nonetheless added to env.validation.ts
 * and .env.example here, since a service whose entire job is protecting
 * secrets can't reasonably ship without its own key being validated at
 * boot. Flagged the same way as every other milestone's minimal,
 * necessary infra addition (see PrismaService, CORS, etc. in earlier
 * commits) rather than silently expanding scope.
 */
@Injectable()
export class TokenEncryptionService {
  private readonly key: Buffer;

  constructor(configService: ConfigService) {
    const hexKey = configService.getOrThrow<string>('TOKEN_ENCRYPTION_KEY');
    this.key = Buffer.from(hexKey, 'hex');

    if (this.key.length !== KEY_LENGTH_BYTES) {
      // Joi's schema already enforces exactly 64 hex chars at boot (see
      // env.validation.ts) — this is a defensive second check, not the
      // primary guard, in case this service is ever constructed outside
      // Nest's normal bootstrap (e.g. directly in a script).
      throw new Error(
        `TOKEN_ENCRYPTION_KEY must decode to exactly ${KEY_LENGTH_BYTES} bytes (64 hex characters) for AES-256-GCM.`,
      );
    }
  }

  encrypt(plaintext: string): string {
    const iv = randomBytes(IV_LENGTH_BYTES);
    const cipher = createCipheriv(ALGORITHM, this.key, iv);

    const ciphertext = Buffer.concat([
      cipher.update(plaintext, 'utf8'),
      cipher.final(),
    ]);
    const authTag = cipher.getAuthTag();

    return Buffer.concat([iv, authTag, ciphertext]).toString('base64');
  }

  decrypt(payload: string): string {
    const raw = Buffer.from(payload, 'base64');

    const iv = raw.subarray(0, IV_LENGTH_BYTES);
    const authTag = raw.subarray(
      IV_LENGTH_BYTES,
      IV_LENGTH_BYTES + AUTH_TAG_LENGTH_BYTES,
    );
    const ciphertext = raw.subarray(IV_LENGTH_BYTES + AUTH_TAG_LENGTH_BYTES);

    const decipher = createDecipheriv(ALGORITHM, this.key, iv);
    decipher.setAuthTag(authTag);

    // Throws if `payload` was tampered with or encrypted under a
    // different key — GCM's authentication tag check fails closed,
    // never silently returns corrupted plaintext.
    const decrypted = Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]);

    return decrypted.toString('utf8');
  }
}
