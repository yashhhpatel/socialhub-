import { Module } from '@nestjs/common';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { SocialAccountsController } from './social-accounts.controller';
import { SocialAccountsService } from './social-accounts.service';

@Module({
  controllers: [SocialAccountsController],
  providers: [SocialAccountsService, InstagramAdapter, TokenEncryptionService],
  exports: [SocialAccountsService],
})
export class SocialAccountsModule {}
