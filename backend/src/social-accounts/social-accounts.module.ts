import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';

import { BillingModule } from '../billing/billing.module';
import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { FacebookAdapter } from './adapters/facebook.adapter';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { LinkedInAdapter } from './adapters/linkedin.adapter';
import { ThreadsAdapter } from './adapters/threads.adapter';
import { XAdapter } from './adapters/x.adapter';
import { SocialAccountsController } from './social-accounts.controller';
import { SocialAccountsService } from './social-accounts.service';
import { SocialTokenService } from './social-token.service';
import { TOKEN_REFRESH_QUEUE } from './token-refresh.constants';
import { TokenRefreshProcessor } from './token-refresh.processor';
import { TokenRefreshScheduler } from './token-refresh.scheduler';

@Module({
  imports: [
    BillingModule,
    // Proactive token-refresh sweep runs on the shared Redis connection
    // (global QueueModule) via this queue (Phase 20).
    BullModule.registerQueue({ name: TOKEN_REFRESH_QUEUE }),
  ],
  controllers: [SocialAccountsController],
  providers: [
    SocialAccountsService,
    SocialTokenService,
    InstagramAdapter,
    XAdapter,
    FacebookAdapter,
    ThreadsAdapter,
    LinkedInAdapter,
    TokenEncryptionService,
    TokenRefreshProcessor,
    TokenRefreshScheduler,
  ],
  // SocialTokenService is exported so PublishingModule can ensure a fresh token
  // before every publish (prevents scheduled posts silently failing on expiry).
  exports: [SocialAccountsService, SocialTokenService],
})
export class SocialAccountsModule {}
