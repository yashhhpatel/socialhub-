import { Processor } from '@nestjs/bullmq';
import { Platform } from '@prisma/client';

import { PUBLISH_QUEUES } from '../publish-queue.constants';
import { PublishingService } from '../publishing.service';
import { BasePublishProcessor } from './base-publish.processor';

/** Worker for the Threads publish queue (Milestone 8.2). */
@Processor(PUBLISH_QUEUES[Platform.threads])
export class ThreadsPublishProcessor extends BasePublishProcessor {
  // Explicit constructor so Nest emits DI metadata on THIS subclass —
  // an inherited-only constructor leaves paramtypes unset and the
  // worker is built with an undefined PublishingService.
  constructor(publishing: PublishingService) {
    super(publishing);
  }
}
