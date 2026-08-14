import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { BestTimeSlot, rankBestTimes } from './best-time-ranking';

/**
 * Best-time-to-post recommendations (Milestone 12.2). Unlike the other AI
 * features this makes NO model call — it's a statistical roll-up of the org's
 * own historical PostMetric data — so it is deliberately NOT metered by
 * QuotaGuard (there's no per-generation model cost to meter). It is still
 * editor+ gated on the controller.
 *
 * A post's time is taken from its publish job's createdAt (when it was sent),
 * and its engagement from the normalized PostMetric — joined org-scoped
 * through publishJob.socialAccount.orgId, the same tenant boundary every
 * analytics query uses.
 */
@Injectable()
export class BestTimeService {
  constructor(private readonly prisma: PrismaService) {}

  async recommend(orgId: string): Promise<BestTimeSlot[]> {
    const metrics = await this.prisma.postMetric.findMany({
      where: { publishJob: { socialAccount: { orgId } } },
      include: { publishJob: true },
    });

    const posts = metrics.map((m) => ({
      postedAt: m.publishJob.createdAt,
      engagement: m.likes + m.comments + m.shares + m.clicks,
    }));

    return rankBestTimes(posts);
  }
}
