import { Injectable } from '@nestjs/common';
import { Platform, PublishJobStatus } from '@prisma/client';

import { PlanLimitsService } from '../billing/plan-limits.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  DashboardActivityItemDto,
  DashboardSummaryDto,
} from './dto/dashboard-summary.dto';

/**
 * Aggregates the Overview dashboard's numbers straight from Postgres, scoped to
 * the caller's org. No dedicated tables — everything is derived from the
 * existing PublishJob / ContentAsset / SocialAccount / AIUsageLog models, so
 * the dashboard can never drift from the real data. AI credits reuse
 * PlanLimitsService (same source as the billing page) so the two agree.
 */
@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly planLimits: PlanLimitsService,
  ) {}

  async summary(orgId: string): Promise<DashboardSummaryDto> {
    const [
      scheduledPosts,
      publishedPosts,
      drafts,
      connectedAccounts,
      usage,
      limits,
      recentActivity,
    ] = await Promise.all([
      // PublishJob has no orgId of its own — scope via its social account.
      this.prisma.publishJob.count({
        where: {
          socialAccount: { orgId },
          status: { in: [PublishJobStatus.scheduled, PublishJobStatus.queued] },
        },
      }),
      this.prisma.publishJob.count({
        where: { socialAccount: { orgId }, status: PublishJobStatus.published },
      }),
      this.prisma.contentAsset.count({
        where: { orgId, approvalStatus: 'draft' },
      }),
      this.prisma.socialAccount.count({
        where: { orgId, status: 'connected' },
      }),
      this.planLimits.usage(orgId),
      this.planLimits.limitsFor(orgId),
      this.buildRecentActivity(orgId),
    ]);

    return {
      scheduledPosts,
      publishedPosts,
      drafts,
      connectedAccounts,
      aiCreditsUsed: usage.aiCreditsUsed,
      // -1 means unlimited (enterprise) — passed through; the client renders it.
      aiCreditsTotal: limits.aiCreditsPerMonth,
      recentActivity,
    };
  }

  /**
   * A real, org-scoped activity feed merged from recent published/scheduled
   * posts, newly connected accounts, and newly saved drafts — newest first.
   */
  private async buildRecentActivity(
    orgId: string,
  ): Promise<DashboardActivityItemDto[]> {
    const [jobs, accounts, draftAssets] = await Promise.all([
      this.prisma.publishJob.findMany({
        where: {
          socialAccount: { orgId },
          status: {
            in: [
              PublishJobStatus.published,
              PublishJobStatus.scheduled,
              PublishJobStatus.queued,
            ],
          },
        },
        orderBy: { updatedAt: 'desc' },
        take: 8,
        select: {
          status: true,
          updatedAt: true,
          variant: { select: { platform: true } },
        },
      }),
      this.prisma.socialAccount.findMany({
        where: { orgId, status: 'connected' },
        orderBy: { createdAt: 'desc' },
        take: 4,
        select: { platform: true, createdAt: true },
      }),
      this.prisma.contentAsset.findMany({
        where: { orgId, approvalStatus: 'draft' },
        orderBy: { createdAt: 'desc' },
        take: 4,
        select: { type: true, createdAt: true },
      }),
    ]);

    const events: { at: Date; description: string; icon: string }[] = [];

    for (const job of jobs) {
      const platform = platformLabel(job.variant.platform);
      if (job.status === PublishJobStatus.published) {
        events.push({
          at: job.updatedAt,
          description: `${platform} post published`,
          icon: 'published',
        });
      } else {
        events.push({
          at: job.updatedAt,
          description: `${platform} post scheduled`,
          icon: 'scheduled',
        });
      }
    }

    for (const account of accounts) {
      events.push({
        at: account.createdAt,
        description: `${platformLabel(account.platform)} account connected`,
        icon: 'account',
      });
    }

    for (const asset of draftAssets) {
      const kind = asset.type === 'video' ? 'Video' : 'Image';
      events.push({
        at: asset.createdAt,
        description: `${kind} draft saved`,
        icon: 'draft',
      });
    }

    return events
      .sort((a, b) => b.at.getTime() - a.at.getTime())
      .slice(0, 6)
      .map((e) => ({
        description: e.description,
        timeAgo: relativeTime(e.at),
        icon: e.icon,
      }));
  }
}

function platformLabel(platform: Platform): string {
  switch (platform) {
    case Platform.instagram:
      return 'Instagram';
    case Platform.facebook:
      return 'Facebook';
    case Platform.threads:
      return 'Threads';
    case Platform.x:
      return 'X';
    case Platform.linkedin:
      return 'LinkedIn';
    default:
      return platform;
  }
}

/** Compact relative time ("just now", "3h ago", "2d ago"). */
function relativeTime(date: Date): string {
  const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}
