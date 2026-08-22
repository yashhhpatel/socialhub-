import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Queue } from 'bullmq';

import {
  TOKEN_REFRESH_CRON,
  TOKEN_REFRESH_JOB,
  TOKEN_REFRESH_QUEUE,
} from './token-refresh.constants';

/**
 * Registers the repeatable token-refresh sweep on the BullMQ queue at boot
 * (Phase 20). Using a BullMQ repeatable job (not a bare @Cron) keeps the
 * schedule in Redis, so exactly one instance runs the sweep even when several
 * API/worker instances are up. Re-adding on every boot is idempotent — BullMQ
 * dedupes on the repeat spec + jobId.
 */
@Injectable()
export class TokenRefreshScheduler implements OnModuleInit {
  private readonly logger = new Logger(TokenRefreshScheduler.name);

  constructor(
    @InjectQueue(TOKEN_REFRESH_QUEUE) private readonly queue: Queue,
  ) {}

  async onModuleInit(): Promise<void> {
    // Best-effort: a transient Redis problem at boot must not crash the API.
    // The sweep is a safety net; if scheduling fails here, the next boot retries
    // and per-publish token refresh still protects individual posts meanwhile.
    try {
      // BullMQ v6 job scheduler (the successor to repeatable jobs). Idempotent
      // by scheduler id, so re-running on every boot just keeps one schedule.
      await this.queue.upsertJobScheduler(
        TOKEN_REFRESH_JOB,
        { pattern: TOKEN_REFRESH_CRON },
        {
          name: TOKEN_REFRESH_JOB,
          opts: { removeOnComplete: true, removeOnFail: 100 },
        },
      );
      this.logger.log(`Scheduled token-refresh sweep (${TOKEN_REFRESH_CRON}).`);
    } catch (err) {
      this.logger.warn(
        `Could not schedule token-refresh sweep: ${
          err instanceof Error ? err.message : err
        }`,
      );
    }
  }
}
