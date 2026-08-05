import { Module } from '@nestjs/common';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import { PublishingController } from './publishing.controller';
import { PublishingService } from './publishing.service';

/**
 * Adapters and TokenEncryptionService are provided directly rather than
 * by importing SocialAccountsModule, which exports only
 * SocialAccountsService — publishing needs the adapters themselves, not
 * the OAuth orchestration around them. Same reasoning as ContentModule
 * (Milestone 4.1); adapters are stateless, so a second instance costs
 * nothing and avoids widening another module's public surface.
 */
@Module({
  controllers: [PublishingController],
  providers: [PublishingService, TokenEncryptionService, InstagramAdapter, XAdapter],
  exports: [PublishingService],
})
export class PublishingModule {}
