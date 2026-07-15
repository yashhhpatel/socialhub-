import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Platform, SocialAccount } from '@prisma/client';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { generatePkcePair } from '../common/crypto/pkce.util';
import { PrismaService } from '../prisma/prisma.service';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { XAdapter } from './adapters/x.adapter';

const STATE_MAX_AGE_MS = 10 * 60 * 1000; // 10 minutes

interface OAuthState {
  orgId: string;
  issuedAt: number;
  /** Only present for PKCE-based platforms (X) — see Milestone 2.3. */
  codeVerifier?: string;
}

/**
 * Orchestrates the OAuth connect flow for every platform: builds a
 * signed `state` param (encrypted, not just base64 — reuses
 * TokenEncryptionService from Milestone 2.1) so each callback can trust
 * which org initiated the request without a DB round trip, and without
 * a client being able to forge or read it. Encrypts tokens before they
 * ever reach Prisma.
 *
 * X (Milestone 2.3) needs PKCE — its verifier is generated here and
 * folded into the SAME encrypted state payload as orgId/issuedAt,
 * rather than needing separate server-side session storage between the
 * authorize redirect and the callback.
 */
@Injectable()
export class SocialAccountsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenEncryption: TokenEncryptionService,
    private readonly instagramAdapter: InstagramAdapter,
    private readonly xAdapter: XAdapter,
  ) {}

  // --- Instagram ---

  buildInstagramAuthorizationUrl(orgId: string): string {
    const state = this.encodeState({ orgId, issuedAt: Date.now() });
    return this.instagramAdapter.getAuthorizationUrl(state);
  }

  async handleInstagramCallback(code: string, rawState: string): Promise<SocialAccount> {
    const { orgId } = this.decodeState(rawState);
    const result = await this.instagramAdapter.connect(code);
    return this.upsertAccount(orgId, Platform.instagram, result);
  }

  // --- X ---

  buildXAuthorizationUrl(orgId: string): string {
    const { verifier, challenge } = generatePkcePair();
    const state = this.encodeState({ orgId, issuedAt: Date.now(), codeVerifier: verifier });
    return this.xAdapter.getAuthorizationUrl(state, challenge);
  }

  async handleXCallback(code: string, rawState: string): Promise<SocialAccount> {
    const { orgId, codeVerifier } = this.decodeState(rawState);
    if (!codeVerifier) {
      // Should be unreachable in practice (only X's own flow produces a
      // state with codeVerifier), but a state built for a different
      // platform being replayed here is exactly the kind of thing to
      // fail loudly on rather than silently proceed without PKCE.
      throw new BadRequestException('OAuth state is missing required PKCE data.');
    }
    const result = await this.xAdapter.connect(code, codeVerifier);
    return this.upsertAccount(orgId, Platform.x, result);
  }

  // --- Shared: list / disconnect (any platform) ---

  listForOrg(orgId: string): Promise<SocialAccount[]> {
    return this.prisma.socialAccount.findMany({ where: { orgId } });
  }

  async disconnect(accountId: string, orgId: string): Promise<void> {
    const account = await this.prisma.socialAccount.findUnique({
      where: { id: accountId },
    });

    // Same NotFoundException whether the row doesn't exist at all or
    // belongs to a different org — never reveal that an account ID
    // exists in someone else's organization.
    if (!account || account.orgId !== orgId) {
      throw new NotFoundException('Social account not found.');
    }

    await this.prisma.socialAccount.delete({ where: { id: accountId } });
  }

  // --- Shared internals ---

  private async upsertAccount(
    orgId: string,
    platform: Platform,
    result: { externalAccountId: string; accessToken: string; refreshToken?: string; expiresAt?: Date },
  ): Promise<SocialAccount> {
    const tokenFields = {
      accessTokenEnc: this.tokenEncryption.encrypt(result.accessToken),
      refreshTokenEnc: result.refreshToken
        ? this.tokenEncryption.encrypt(result.refreshToken)
        : null,
      expiresAt: result.expiresAt,
      status: 'connected' as const,
    };

    return this.prisma.socialAccount.upsert({
      where: {
        orgId_platform_externalAccountId: {
          orgId,
          platform,
          externalAccountId: result.externalAccountId,
        },
      },
      create: { orgId, platform, externalAccountId: result.externalAccountId, ...tokenFields },
      update: tokenFields,
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
