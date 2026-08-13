import { Module } from '@nestjs/common';

import { ContentModule } from '../content/content.module';
import { FacebookAdapter } from '../social-accounts/adapters/facebook.adapter';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { ThreadsAdapter } from '../social-accounts/adapters/threads.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import { AiController } from './ai.controller';
import { AiGatewayService } from './ai-gateway.service';
import { CaptionService } from './caption.service';
import { QuotaGuard } from './quota.guard';

/**
 * ContentModule is imported (not duplicated) because it exports
 * ContentService — captioning genuinely needs the asset-loading and
 * org-scoping logic, unlike the adapters, which are provided directly for
 * their stateless capabilities() metadata (same pattern as ContentModule
 * and PublishingModule).
 */
@Module({
  imports: [ContentModule],
  controllers: [AiController],
  providers: [
    AiGatewayService,
    CaptionService,
    QuotaGuard,
    InstagramAdapter,
    XAdapter,
    FacebookAdapter,
    ThreadsAdapter,
  ],
  exports: [AiGatewayService],
})
export class AiModule {}
