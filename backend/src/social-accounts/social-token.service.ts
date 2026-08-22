import { Injectable, Logger } from '@nestjs/common';
import {
  Platform,
  SocialAccount,
  SocialAccountStatus,
} from '@prisma/client';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { PrismaService } from '../prisma/prisma.service';
import { PlatformAdapter } from './adapters/adapter.interface';
import { FacebookAdapter } from './adapters/facebook.adapter';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { LinkedInAdapter } from './adapters/linkedin.adapter';
import { ThreadsAdapter } from './adapters/threads.adapter';
import { XAdapter } from './adapters/x.adapter';

/** Refresh a token this far ahead of its expiry (proactive window). */
export const TOKEN_REFRESH_THRESHOLD_MS = 24 * 60 * 60 * 1000; // 24h

/**
 * Thrown when a social account can't be used to publish because its token is
 * expired/revoked and could not be refreshed — the account must be reconnected
 * by the user. Publishing catches this and fails the job terminally (no retry)
 * rather than letting it silently error out on every attempt.
 */
export class TokenReconnectRequiredError extends Error {
  constructor(
    public readonly platform: Platform,
    public readonly status: SocialAccountStatus,
    message?: string,
  ) {
    super(message ?? `Reconnect required for ${platform} (${status}).`);
    this.name = 'TokenReconnectRequiredError';
  }
}

/**
 * Owns social-token freshness (Phase 20): proactive refresh before expiry and
 * marking an account as needing reconnection when refresh is impossible.
 *
 * Reuses the existing per-platform adapters (their `refresh()` methods) and
 * TokenEncryptionService — no new token storage. Refreshed tokens are written
 * back encrypted; X/LinkedIn rotate their refresh token, so the returned one is
 * persisted. IG/Threads/FB refresh in place using the current access token, so
 * when no stored refresh token exists the access token is used as the input.
 */
@Injectable()
export class SocialTokenService {
  private readonly logger = new Logger(SocialTokenService.name);
  private readonly adapters: Partial<Record<Platform, PlatformAdapter>>;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenEncryption: TokenEncryptionService,
    instagram: InstagramAdapter,
    x: XAdapter,
    facebook: FacebookAdapter,
    threads: ThreadsAdapter,
    linkedin: LinkedInAdapter,
  ) {
    this.adapters = {
      [Platform.instagram]: instagram,
      [Platform.x]: x,
      [Platform.facebook]: facebook,
      [Platform.threads]: threads,
      [Platform.linkedin]: linkedin,
    };
  }

  /** True for any status that requires the user to reconnect the account. */
  static needsReconnect(status: SocialAccountStatus): boolean {
    return status !== SocialAccountStatus.connected;
  }

  /**
   * Returns a usable, decrypted access token for a publish, refreshing first if
   * it's within the proactive window or already past expiry. Throws
   * TokenReconnectRequiredError if the account is (or becomes) unusable.
   */
  async ensureFreshAccessToken(account: SocialAccount): Promise<string> {
    if (SocialTokenService.needsReconnect(account.status)) {
      throw new TokenReconnectRequiredError(account.platform, account.status);
    }

    if (this.isDueForRefresh(account)) {
      const refreshed = await this.refreshAccount(account);
      return this.tokenEncryption.decrypt(refreshed.accessTokenEnc);
    }

    return this.tokenEncryption.decrypt(account.accessTokenEnc);
  }

  /** Whether an account's token is expiring within the proactive window. */
  isDueForRefresh(account: SocialAccount, now: Date = new Date()): boolean {
    if (!account.expiresAt) return false; // no expiry → nothing to pre-refresh
    return account.expiresAt.getTime() - now.getTime() <= TOKEN_REFRESH_THRESHOLD_MS;
  }

  /**
   * Refreshes one account's token and persists the result. On success sets
   * status back to `connected`; on failure marks it expired/revoked/error and
   * throws TokenReconnectRequiredError.
   */
  async refreshAccount(account: SocialAccount): Promise<SocialAccount> {
    const adapter = this.adapters[account.platform];
    if (!adapter) {
      throw new TokenReconnectRequiredError(
        account.platform,
        SocialAccountStatus.error,
        `No adapter for platform ${account.platform}.`,
      );
    }

    // IG/Threads/FB refresh in place from the current access token; X/LinkedIn
    // use the stored (rotating) refresh token. "Refresh token if present, else
    // access token" covers both.
    const tokenForRefresh = account.refreshTokenEnc
      ? this.tokenEncryption.decrypt(account.refreshTokenEnc)
      : this.tokenEncryption.decrypt(account.accessTokenEnc);

    try {
      const refreshed = await adapter.refresh(tokenForRefresh);
      return await this.prisma.socialAccount.update({
        where: { id: account.id },
        data: {
          accessTokenEnc: this.tokenEncryption.encrypt(refreshed.accessToken),
          // Persist a rotated refresh token; keep the existing one otherwise.
          refreshTokenEnc: refreshed.refreshToken
            ? this.tokenEncryption.encrypt(refreshed.refreshToken)
            : account.refreshTokenEnc,
          expiresAt: refreshed.expiresAt ?? account.expiresAt,
          status: SocialAccountStatus.connected,
        },
      });
    } catch (err) {
      const status = this.statusForFailure(account, err);
      await this.prisma.socialAccount.update({
        where: { id: account.id },
        data: { status },
      });
      // Log without the token or full provider body — just platform + reason.
      this.logger.warn(
        `Token refresh failed for account ${account.id} (${account.platform}) → ${status}`,
      );
      throw new TokenReconnectRequiredError(account.platform, status);
    }
  }

  /**
   * Sweep: refresh every connected account whose token is within the proactive
   * window. Best-effort and isolated per account — one failure marks that
   * account for reconnection and never aborts the rest. Returns a small summary
   * for the caller/log.
   */
  async refreshDueAccounts(
    now: Date = new Date(),
  ): Promise<{ due: number; refreshed: number; needsReconnect: number }> {
    const threshold = new Date(now.getTime() + TOKEN_REFRESH_THRESHOLD_MS);
    const due = await this.prisma.socialAccount.findMany({
      where: {
        status: SocialAccountStatus.connected,
        expiresAt: { not: null, lte: threshold },
      },
    });

    let refreshed = 0;
    let needsReconnect = 0;
    for (const account of due) {
      try {
        await this.refreshAccount(account);
        refreshed += 1;
      } catch {
        // refreshAccount already persisted the reconnect status + logged.
        needsReconnect += 1;
      }
    }

    if (due.length > 0) {
      this.logger.log(
        `Token refresh sweep: ${refreshed} refreshed, ${needsReconnect} need reconnect (of ${due.length} due).`,
      );
    }
    return { due: due.length, refreshed, needsReconnect };
  }

  private statusForFailure(
    account: SocialAccount,
    err: unknown,
  ): SocialAccountStatus {
    const msg = (err instanceof Error ? err.message : String(err)).toLowerCase();
    if (/invalid_grant|revoked|unauthorized|invalid.?token|\b400\b|\b401\b/.test(msg)) {
      return SocialAccountStatus.revoked;
    }
    if (account.expiresAt && account.expiresAt.getTime() <= Date.now()) {
      return SocialAccountStatus.expired;
    }
    return SocialAccountStatus.error;
  }
}
