import { Injectable } from '@nestjs/common';
import { PlanTier, PublishJobStatus, SocialAccountStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { AdminOverviewDto } from './dto/admin-overview.dto';

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Cross-tenant KPIs for the admin Overview (Phase 21.2). All counts span every
 * org (no orgId filter — that's the whole point of the admin panel) and derive
 * from existing tables; no new data is stored and no secrets are read.
 */
@Injectable()
export class AdminOverviewService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(): Promise<AdminOverviewDto> {
    const since = new Date(Date.now() - THIRTY_DAYS_MS);

    const [
      totalOrganizations,
      totalUsers,
      newOrganizations30d,
      newUsers30d,
      activeOrganizations,
      planGroups,
      connectedAccounts,
      accountsNeedingReconnect,
      publishedPosts,
      failedPosts,
      unverifiedUsers,
      mfaEnabledUsers,
    ] = await Promise.all([
      this.prisma.organization.count(),
      this.prisma.user.count(),
      this.prisma.organization.count({ where: { createdAt: { gte: since } } }),
      this.prisma.user.count({ where: { createdAt: { gte: since } } }),
      this.prisma.organization.count({
        where: { socialAccounts: { some: { status: SocialAccountStatus.connected } } },
      }),
      this.prisma.organization.groupBy({
        by: ['planTier'],
        _count: { _all: true },
      }),
      this.prisma.socialAccount.count({
        where: { status: SocialAccountStatus.connected },
      }),
      this.prisma.socialAccount.count({
        where: { status: { not: SocialAccountStatus.connected } },
      }),
      this.prisma.publishJob.count({
        where: { status: PublishJobStatus.published },
      }),
      this.prisma.publishJob.count({ where: { status: PublishJobStatus.failed } }),
      this.prisma.user.count({ where: { emailVerifiedAt: null } }),
      this.prisma.user.count({ where: { mfaEnabled: true } }),
    ]);

    const terminal = publishedPosts + failedPosts;
    const publishFailureRate = terminal === 0 ? 0 : failedPosts / terminal;

    // Ensure every tier appears (0 when none), in a stable order.
    const countByTier = new Map(
      planGroups.map((g) => [g.planTier, g._count._all]),
    );
    const planDistribution = Object.values(PlanTier).map((tier) => ({
      tier,
      count: countByTier.get(tier) ?? 0,
    }));

    return {
      totalOrganizations,
      totalUsers,
      newOrganizations30d,
      newUsers30d,
      activeOrganizations,
      planDistribution,
      connectedAccounts,
      accountsNeedingReconnect,
      publishedPosts,
      failedPosts,
      publishFailureRate,
      unverifiedUsers,
      mfaEnabledUsers,
    };
  }
}
