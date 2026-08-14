import { Injectable, Logger } from '@nestjs/common';
import { IngestionStatus, PublishJobStatus, SocialAccountStatus } from '@prisma/client';

import { TokenEncryptionService } from '../../common/crypto/token-encryption.service';
import { PrismaService } from '../../prisma/prisma.service';
import { MetricFetcher } from './metric-fetcher';
import { normalizeMetrics } from './metric-normalization';

export interface IngestionSummary {
  runId: string;
  processed: number;
  failed: number;
}

/**
 * Pulls fresh metrics for every published post into normalized PostMetric
 * rows (Phase 10). Runs as a system-wide job (all orgs) on a schedule —
 * see ingestion.cron.ts.
 *
 * Each post is independent: one post's failed fetch (a revoked token, a
 * platform 5xx, a not-yet-wired platform) is counted and skipped, never
 * aborting the run. The whole thing is wrapped in an IngestionRun row so a
 * pull's outcome is recorded and the dashboard can show "last updated".
 */
@Injectable()
export class IngestionService {
  private readonly logger = new Logger(IngestionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenEncryption: TokenEncryptionService,
    private readonly metricFetcher: MetricFetcher,
  ) {}

  async runIngestion(): Promise<IngestionSummary> {
    const run = await this.prisma.ingestionRun.create({
      data: { status: IngestionStatus.running },
    });

    let processed = 0;
    let failed = 0;

    try {
      // Every published post that still has a reachable account and a
      // platform id to look up. onDelete rules keep these rows around even
      // after a disconnect, so the connected-status filter is what excludes
      // posts we can no longer authenticate for.
      const jobs = await this.prisma.publishJob.findMany({
        where: {
          status: PublishJobStatus.published,
          externalPostId: { not: null },
          socialAccount: { status: SocialAccountStatus.connected },
        },
        include: { socialAccount: true },
      });

      for (const job of jobs) {
        try {
          const token = this.tokenEncryption.decrypt(job.socialAccount.accessTokenEnc);
          const raw = await this.metricFetcher.fetchRaw(
            job.socialAccount.platform,
            job.externalPostId as string,
            token,
          );
          const metrics = normalizeMetrics(job.socialAccount.platform, raw);

          await this.prisma.postMetric.upsert({
            where: { publishJobId: job.id },
            create: { publishJobId: job.id, ...metrics, capturedAt: new Date() },
            update: { ...metrics, capturedAt: new Date() },
          });
          processed++;
        } catch (error) {
          failed++;
          this.logger.warn(
            `Metric ingestion failed for job ${job.id} (${job.socialAccount.platform}): ${
              error instanceof Error ? error.message : String(error)
            }`,
          );
        }
      }

      await this.prisma.ingestionRun.update({
        where: { id: run.id },
        data: {
          status: IngestionStatus.success,
          postsProcessed: processed,
          postsFailed: failed,
          finishedAt: new Date(),
        },
      });
    } catch (error) {
      // A failure OUTSIDE a single post (e.g. the initial query) — the run
      // as a whole failed, recorded so it isn't mistaken for "no data".
      await this.prisma.ingestionRun.update({
        where: { id: run.id },
        data: {
          status: IngestionStatus.failed,
          postsProcessed: processed,
          postsFailed: failed,
          error: error instanceof Error ? error.message : String(error),
          finishedAt: new Date(),
        },
      });
      throw error;
    }

    return { runId: run.id, processed, failed };
  }
}
