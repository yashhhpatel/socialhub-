import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { Platform } from '@prisma/client';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { FacebookAdapter } from '../social-accounts/adapters/facebook.adapter';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import { PublishingController } from './publishing.controller';
import { PublishingService } from './publishing.service';
import { FacebookPublishProcessor } from './processors/facebook-publish.processor';
import { InstagramPublishProcessor } from './processors/instagram-publish.processor';
import { XPublishProcessor } from './processors/x-publish.processor';
import { PUBLISH_QUEUES } from './publish-queue.constants';
import { ScheduledPublishDispatcher } from './schedule.cron';

/**
 * Adapters and TokenEncryptionService are provided directly rather than
 * by importing SocialAccountsModule, which exports only
 * SocialAccountsService — publishing needs the adapters themselves, not
 * the OAuth orchestration around them. Same reasoning as ContentModule
 * (Milestone 4.1); adapters are stateless, so a second instance costs
 * nothing and avoids widening another module's public surface.
 *
 * Milestone 7.2 registers one queue per platform (isolated retry timelines)
 * and a worker (processor) per queue; the shared Redis connection comes from
 * the global QueueModule.
 */
@Module({
  imports: [
    BullModule.registerQueue(
      { name: PUBLISH_QUEUES[Platform.instagram] },
      { name: PUBLISH_QUEUES[Platform.x] },
      { name: PUBLISH_QUEUES[Platform.facebook] },
    ),
  ],
  controllers: [PublishingController],
  providers: [
    PublishingService,
    TokenEncryptionService,
    InstagramAdapter,
    XAdapter,
    FacebookAdapter,
    InstagramPublishProcessor,
    XPublishProcessor,
    FacebookPublishProcessor,
    ScheduledPublishDispatcher,
  ],
  exports: [PublishingService],
})
export class PublishingModule {}
