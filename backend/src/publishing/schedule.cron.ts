import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PublishingService } from './publishing.service';

/**
 * Fires due scheduled publishes (Milestone 7.3).
 *
 * Every 30 seconds it asks the service to enqueue any scheduled job whose
 * time has passed. 30s bounds how late a post can go out to well under a
 * minute, which is fine for social scheduling, without hammering the DB.
 * The heavy lifting — the atomic claim that makes this safe to run
 * concurrently — lives in dispatchDueScheduledJobs; this is only the timer.
 */
@Injectable()
export class ScheduledPublishDispatcher {
  private readonly logger = new Logger(ScheduledPublishDispatcher.name);

  constructor(private readonly publishing: PublishingService) {}

  @Cron(CronExpression.EVERY_30_SECONDS)
  async dispatchDue(): Promise<void> {
    try {
      const dispatched = await this.publishing.dispatchDueScheduledJobs();
      if (dispatched > 0) {
        this.logger.log(`Dispatched ${dispatched} scheduled publish job(s).`);
      }
    } catch (error) {
      // A failing tick must not crash the scheduler — the next tick retries.
      this.logger.error(
        `Scheduled-publish dispatch failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }
}
