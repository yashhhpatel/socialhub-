import { Processor } from '@nestjs/bullmq';
import { Platform } from '@prisma/client';

import { PUBLISH_QUEUES } from '../publish-queue.constants';
import { BasePublishProcessor } from './base-publish.processor';

/** Worker for the Facebook publish queue (Milestone 8.1). */
@Processor(PUBLISH_QUEUES[Platform.facebook])
export class FacebookPublishProcessor extends BasePublishProcessor {}
