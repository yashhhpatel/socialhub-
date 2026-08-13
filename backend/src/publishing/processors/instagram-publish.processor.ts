import { Processor } from '@nestjs/bullmq';
import { Platform } from '@prisma/client';

import { PUBLISH_QUEUES } from '../publish-queue.constants';
import { BasePublishProcessor } from './base-publish.processor';

/** Worker for the Instagram publish queue (Milestone 7.2). */
@Processor(PUBLISH_QUEUES[Platform.instagram])
export class InstagramPublishProcessor extends BasePublishProcessor {}
