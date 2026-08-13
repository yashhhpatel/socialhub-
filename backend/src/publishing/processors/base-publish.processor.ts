import { WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';

import {
  PUBLISH_JOB_OPTIONS,
  PublishJobData,
} from '../publish-queue.constants';
import { PublishingService } from '../publishing.service';

/**
 * Shared body for every per-platform publish worker (Milestone 7.2).
 *
 * Each platform gets its OWN @Processor subclass (and therefore its own
 * BullMQ worker on its own queue) so their retry timelines are isolated —
 * that isolation is the reason the queues are split in the first place. The
 * work itself is identical, so it lives here once.
 *
 * `job.attemptsMade` is 0 on the first attempt and increments per retry
 * (verified against bullmq@6); executePublish uses it to know when the
 * final attempt has failed and the DB row should read `failed`.
 */
export abstract class BasePublishProcessor extends WorkerHost {
  constructor(protected readonly publishing: PublishingService) {
    super();
  }

  async process(job: Job<PublishJobData>): Promise<void> {
    await this.publishing.executePublish(job.data, {
      attemptsMade: job.attemptsMade,
      maxAttempts: job.opts.attempts ?? PUBLISH_JOB_OPTIONS.attempts,
    });
  }
}
