import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Platform, SocialAccount, SocialAccountStatus } from '@prisma/client';
import { randomBytes } from 'crypto';

import { PlanLimitsService } from '../billing/plan-limits.service';
import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { generatePkcePair } from '../common/crypto/pkce.util';
import { PrismaService } from '../prisma/prisma.service';
import { FacebookAdapter } from './adapters/facebook.adapter';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { LinkedInAdapter } from './adapters/linkedin.adapter';
import { ThreadsAdapter } from './adapters/threads.adapter';
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
    private readonly facebookAdapter: FacebookAdapter,
    private readonly threadsAdapter: ThreadsAdapter,
    private readonly linkedinAdapter: LinkedInAdapter,
    private readonly planLimits: PlanLimitsService,
  ) {}

  // --- Instagram ---

  buildInstagramAuthorizationUrl(orgId: string): string {
    return this.buildAuthorizationUrl('Instagram', () => {
      const state = this.encodeState({ orgId, issuedAt: Date.now() });
      return this.instagramAdapter.getAuthorizationUrl(state);
    });
  }

  async handleInstagramCallback(code: string, rawState: string): Promise<SocialAccount> {
    const { orgId } = this.decodeState(rawState);
    const result = await this.instagramAdapter.connect(code);
    return this.upsertAccount(orgId, Platform.instagram, result);
  }

  // --- X ---

  buildXAuthorizationUrl(orgId: string): string {
    return this.buildAuthorizationUrl('X', () => {
      const { verifier, challenge } = generatePkcePair();
      const state = this.encodeState({
        orgId,
        issuedAt: Date.now(),
        codeVerifier: verifier,
      });
      return this.xAdapter.getAuthorizationUrl(state, challenge);
    });
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

  // --- Facebook (Milestone 8.1) ---

  buildFacebookAuthorizationUrl(orgId: string): string {
    return this.buildAuthorizationUrl('Facebook', () => {
      const state = this.encodeState({ orgId, issuedAt: Date.now() });
      return this.facebookAdapter.getAuthorizationUrl(state);
    });
  }

  async handleFacebookCallback(code: string, rawState: string): Promise<SocialAccount> {
    const { orgId } = this.decodeState(rawState);
    const result = await this.facebookAdapter.connect(code);
    return this.upsertAccount(orgId, Platform.facebook, result);
  }

  // --- Threads (Milestone 8.2) ---

  buildThreadsAuthorizationUrl(orgId: string): string {
    return this.buildAuthorizationUrl('Threads', () => {
      const state = this.encodeState({ orgId, issuedAt: Date.now() });
      return this.threadsAdapter.getAuthorizationUrl(state);
    });
  }

  async handleThreadsCallback(code: string, rawState: string): Promise<SocialAccount> {
    const { orgId } = this.decodeState(rawState);
    const result = await this.threadsAdapter.connect(code);
    return this.upsertAccount(orgId, Platform.threads, result);
  }

  // --- LinkedIn (Milestone 8.3) ---

  buildLinkedInAuthorizationUrl(orgId: string): string {
    return this.buildAuthorizationUrl('LinkedIn', () => {
      const state = this.encodeState({ orgId, issuedAt: Date.now() });
      return this.linkedinAdapter.getAuthorizationUrl(state);
    });
  }

  async handleLinkedInCallback(code: string, rawState: string): Promise<SocialAccount> {
    const { orgId } = this.decodeState(rawState);
    const result = await this.linkedinAdapter.connect(code);
    return this.upsertAccount(orgId, Platform.linkedin, result);
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

    // SOFT disconnect: mark revoked and drop the refresh token, rather than
    // hard-deleting. The row is referenced by publish_job with onDelete:
    // Restrict precisely so published history survives a disconnect — a
    // DELETE throws a FK violation once the account has ever published.
    // Reconnecting the same account later reactivates this row (the connect
    // upsert keys on orgId+platform+externalAccountId), now with a fresh
    // token/scope.
    await this.prisma.socialAccount.update({
      where: { id: accountId },
      data: {
        status: SocialAccountStatus.revoked,
        refreshTokenEnc: null,
      },
    });
  }

  // --- Meta compliance: deauthorize & data deletion callbacks ---
  //
  // Both are triggered by Meta (not a signed-in user) via a verified signed
  // request; the controller verifies the signature before calling these. The
  // person is identified by their platform *user* id, which we match against
  // both externalUserId and externalAccountId (the latter covers Instagram/
  // Threads, where the account id is the user id).

  /**
   * Delete every connected account for this platform belonging to the given
   * platform user. Idempotent — a repeat callback for an already-removed user
   * simply deletes nothing. Returns how many rows were removed.
   */
  async purgePlatformUser(platform: Platform, externalUserId: string): Promise<number> {
    const result = await this.prisma.socialAccount.deleteMany({
      where: {
        platform,
        OR: [{ externalUserId }, { externalAccountId: externalUserId }],
      },
    });
    return result.count;
  }

  /**
   * Handle a Meta data-deletion request: purge the user's accounts and record
   * the outcome so the status URL handed back to Meta can confirm it. Returns
   * the confirmation code Meta requires in the callback response.
   */
  async recordDataDeletion(
    platform: Platform,
    externalUserId: string,
  ): Promise<string> {
    await this.purgePlatformUser(platform, externalUserId);
    const confirmationCode = randomBytes(16).toString('hex');
    await this.prisma.dataDeletionRequest.create({
      data: { platform, externalUserId, confirmationCode, status: 'completed' },
    });
    return confirmationCode;
  }

  /** Look up a data-deletion request by its confirmation code (status URL). */
  getDataDeletionStatus(confirmationCode: string) {
    return this.prisma.dataDeletionRequest.findUnique({
      where: { confirmationCode },
    });
  }

  // --- Shared internals ---

  /**
   * Builds a platform's OAuth authorization URL, turning the one failure a
   * user can actually hit — the platform's OAuth app credentials not being
   * configured on this server — into a clean, actionable 503 instead of an
   * opaque 500 stack trace.
   *
   * The adapters read their credentials via ConfigService.getOrThrow(),
   * which throws `Configuration key "..." does not exist` when an env var is
   * missing. We recognise exactly that message and rethrow a friendly
   * ServiceUnavailableException; any other error is a real bug and is left
   * to propagate unchanged.
   */
  private buildAuthorizationUrl(label: string, build: () => string): string {
    try {
      return build();
    } catch (err) {
      if (err instanceof Error && /does not exist/i.test(err.message)) {
        throw new ServiceUnavailableException(
          `${label} connecting isn't set up on this server yet. ` +
            `An administrator needs to add ${label}'s OAuth app credentials first.`,
        );
      }
      throw err;
    }
  }

  private async upsertAccount(
    orgId: string,
    platform: Platform,
    result: {
      externalAccountId: string;
      externalUserId?: string;
      accessToken: string;
      refreshToken?: string;
      expiresAt?: Date;
    },
  ): Promise<SocialAccount> {
    // Plan-gating (Phase 18): a NEW connection must fit the plan's account
    // cap. Reconnecting an already-connected account (same platform + external
    // id) is an update, so it's always allowed even at the limit.
    const existing = await this.prisma.socialAccount.findUnique({
      where: {
        orgId_platform_externalAccountId: {
          orgId,
          platform,
          externalAccountId: result.externalAccountId,
        },
      },
      select: { id: true },
    });
    if (!existing) {
      await this.planLimits.assertCanConnectSocialAccount(orgId);
    }

    const fields = {
      externalUserId: result.externalUserId ?? null,
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
      create: { orgId, platform, externalAccountId: result.externalAccountId, ...fields },
      update: fields,
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
