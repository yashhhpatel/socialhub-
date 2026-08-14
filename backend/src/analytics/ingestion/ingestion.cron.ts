import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { IngestionService } from './ingestion.service';

/**
 * Scheduled metric pull (Phase 10). Hourly: platform insights update on the
 * order of minutes-to-hours and their APIs are rate-limited, so pulling
 * every post's numbers more often would burn quota for data that hasn't
 * moved. The atomic per-post work lives in IngestionService; this is only
 * the timer, and a failing tick is logged, never allowed to crash the
 * scheduler.
 */
@Injectable()
export class IngestionCron {
  private readonly logger = new Logger(IngestionCron.name);

  constructor(private readonly ingestion: IngestionService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async pull(): Promise<void> {
    try {
      const summary = await this.ingestion.runIngestion();
      this.logger.log(
        `Metric ingestion run ${summary.runId}: ${summary.processed} updated, ${summary.failed} failed.`,
      );
    } catch (error) {
      this.logger.error(
        `Metric ingestion run failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }
}
