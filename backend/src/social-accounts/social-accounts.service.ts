import { BadRequestException, Injectable } from '@nestjs/common';
import { Platform, SocialAccount } from '@prisma/client';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { PrismaService } from '../prisma/prisma.service';
import { InstagramAdapter } from './adapters/instagram.adapter';

const STATE_MAX_AGE_MS = 10 * 60 * 1000; // 10 minutes

interface OAuthState {
  orgId: string;
  issuedAt: number;
}

/**
 * Orchestrates the OAuth connect flow: builds a signed `state` param
 * (encrypted, not just base64 — reuses TokenEncryptionService from
 * Milestone 2.1) so the callback can trust which org initiated the
 * request without a DB round trip, and without a client being able to
 * forge or read it. Encrypts tokens before they ever reach Prisma.
 */
@Injectable()
export class SocialAccountsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenEncryption: TokenEncryptionService,
    private readonly instagramAdapter: InstagramAdapter,
  ) {}

  buildInstagramAuthorizationUrl(orgId: string): string {
    const state = this.encodeState({ orgId, issuedAt: Date.now() });
    return this.instagramAdapter.getAuthorizationUrl(state);
  }

  async handleInstagramCallback(
    code: string,
    rawState: string,
  ): Promise<SocialAccount> {
    const { orgId } = this.decodeState(rawState);
    const result = await this.instagramAdapter.connect(code);

    return this.prisma.socialAccount.upsert({
      where: {
        orgId_platform_externalAccountId: {
          orgId,
          platform: Platform.instagram,
          externalAccountId: result.externalAccountId,
        },
      },
      create: {
        orgId,
        platform: Platform.instagram,
        externalAccountId: result.externalAccountId,
        accessTokenEnc: this.tokenEncryption.encrypt(result.accessToken),
        refreshTokenEnc: result.refreshToken
          ? this.tokenEncryption.encrypt(result.refreshToken)
          : null,
        expiresAt: result.expiresAt,
        status: 'connected',
      },
      update: {
        accessTokenEnc: this.tokenEncryption.encrypt(result.accessToken),
        refreshTokenEnc: result.refreshToken
          ? this.tokenEncryption.encrypt(result.refreshToken)
          : null,
        expiresAt: result.expiresAt,
        status: 'connected',
      },
    });
  }

  private encodeState(state: OAuthState): string {
    return this.tokenEncryption.encrypt(JSON.stringify(state));
  }

  private decodeState(rawState: string): OAuthState {
    let decoded: OAuthState;

    try {
      decoded = JSON.parse(this.tokenEncryption.decrypt(rawState)) as OAuthState;
    } catch {
      // Covers both a tampered/forged state (fails GCM auth tag check
      // inside decrypt) and malformed JSON — either way, not trustworthy.
      throw new BadRequestException('Invalid or tampered OAuth state parameter.');
    }

    const age = Date.now() - decoded.issuedAt;
    if (age > STATE_MAX_AGE_MS || age < 0) {
      // age < 0 would mean a timestamp claiming to be from the future —
      // also not trustworthy, treated the same as expired.
      throw new BadRequestException(
        'OAuth state has expired. Please try connecting again.',
      );
    }

    return decoded;
  }
}
