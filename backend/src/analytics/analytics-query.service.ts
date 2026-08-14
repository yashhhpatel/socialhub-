import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import {
  AnalyticsOverview,
  MetricRow,
  aggregateOverview,
} from './analytics-aggregation';

/**
 * Read side of analytics (Milestone 10.3) — turns stored PostMetric rows
 * into the dashboard's shapes, always org-scoped through
 * publishJob.socialAccount.orgId (the tenant boundary every query enforces).
 * Both the GraphQL resolver and the REST fallback call this, so they can't
 * diverge.
 */
@Injectable()
export class AnalyticsQueryService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(orgId: string): Promise<AnalyticsOverview> {
    const rows = await this.loadRows({ publishJob: { socialAccount: { orgId } } });
    return aggregateOverview(rows);
  }

  /** Metrics for one variant's published posts (may be several platforms). */
  async postMetrics(orgId: string, variantId: string): Promise<MetricRow[]> {
    return this.loadRows({
      publishJob: { variantId, socialAccount: { orgId } },
    });
  }

  private async loadRows(publishJobWhere: {
    publishJob: Record<string, unknown>;
  }): Promise<MetricRow[]> {
    const metrics = await this.prisma.postMetric.findMany({
      where: publishJobWhere,
      include: {
        publishJob: { include: { socialAccount: true } },
      },
      orderBy: { capturedAt: 'desc' },
    });

    return metrics.map((m) => ({
      publishJobId: m.publishJobId,
      variantId: m.publishJob.variantId,
      platform: m.publishJob.socialAccount.platform,
      externalPostId: m.publishJob.externalPostId,
      metrics: {
        impressions: m.impressions,
        reach: m.reach,
        likes: m.likes,
        comments: m.comments,
        shares: m.shares,
        clicks: m.clicks,
      },
      capturedAt: m.capturedAt,
    }));
  }
}
