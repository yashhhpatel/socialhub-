import { Injectable, NotFoundException } from '@nestjs/common';
import { Platform, SocialAccountStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  SocialTokenService,
  TokenReconnectRequiredError,
} from '../social-accounts/social-token.service';
import {
  AdminRefreshResultDto,
  AdminSocialAccountListDto,
} from './dto/admin-social-accounts.dto';

const MAX_LIMIT = 100;

/**
 * Cross-tenant social-account health for the admin panel (Phase 21.5) — the
 * reconnect queue. Reuses SocialTokenService for force-refresh. Token
 * ciphertext is never selected into a response.
 */
@Injectable()
export class AdminSocialAccountsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly socialTokens: SocialTokenService,
  ) {}

  async list(params: {
    status?: string;
    platform?: string;
    page?: number;
    limit?: number;
  }): Promise<AdminSocialAccountListDto> {
    const page = Math.max(1, params.page ?? 1);
    const limit = Math.min(MAX_LIMIT, Math.max(1, params.limit ?? 20));

    const where: {
      status?: SocialAccountStatus;
      platform?: Platform;
    } = {};
    if (params.status && isStatus(params.status)) where.status = params.status;
    if (params.platform && isPlatform(params.platform)) {
      where.platform = params.platform;
    }

    const [total, rows] = await Promise.all([
      this.prisma.socialAccount.count({ where }),
      this.prisma.socialAccount.findMany({
        where,
        // Unhealthy first (so the reconnect queue surfaces), then newest.
        orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          orgId: true,
          platform: true,
          externalAccountId: true,
          status: true,
          expiresAt: true,
          createdAt: true,
          organization: { select: { name: true } },
        },
      }),
    ]);

    return {
      total,
      page,
      limit,
      data: rows.map((a) => ({
        id: a.id,
        orgId: a.orgId,
        orgName: a.organization.name,
        platform: a.platform,
        externalAccountId: a.externalAccountId,
        status: a.status,
        expiresAt: a.expiresAt,
        createdAt: a.createdAt,
      })),
    };
  }

  /**
   * Force a token refresh. On success the status returns to `connected`; if the
   * token can't be refreshed the account is marked for reconnection and the
   * outcome (needsReconnect) is reported — this is a completed admin action, not
   * a request error.
   */
  async refresh(id: string): Promise<AdminRefreshResultDto> {
    const account = await this.prisma.socialAccount.findUnique({ where: { id } });
    if (!account) throw new NotFoundException('Social account not found.');

    try {
      const updated = await this.socialTokens.refreshAccount(account);
      return { id, status: updated.status, needsReconnect: false };
    } catch (err) {
      if (err instanceof TokenReconnectRequiredError) {
        return { id, status: err.status, needsReconnect: true };
      }
      throw err;
    }
  }

  /** Disconnect (delete) a social account across tenants. */
  async disconnect(id: string): Promise<void> {
    const account = await this.prisma.socialAccount.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!account) throw new NotFoundException('Social account not found.');
    await this.prisma.socialAccount.delete({ where: { id } });
  }
}

function isStatus(value: string): value is SocialAccountStatus {
  return (Object.values(SocialAccountStatus) as string[]).includes(value);
}

function isPlatform(value: string): value is Platform {
  return (Object.values(Platform) as string[]).includes(value);
}
