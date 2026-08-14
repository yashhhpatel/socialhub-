import { Processor } from '@nestjs/bullmq';
import { Platform } from '@prisma/client';

import { PUBLISH_QUEUES } from '../publish-queue.constants';
import { BasePublishProcessor } from './base-publish.processor';

/** Worker for the LinkedIn publish queue (Milestone 8.3). */
@Processor(PUBLISH_QUEUES[Platform.linkedin])
export class LinkedInPublishProcessor extends BasePublishProcessor {}
