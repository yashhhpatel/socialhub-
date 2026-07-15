import { Module } from '@nestjs/common';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { XAdapter } from './adapters/x.adapter';
import { SocialAccountsController } from './social-accounts.controller';
import { SocialAccountsService } from './social-accounts.service';

@Module({
  controllers: [SocialAccountsController],
  providers: [SocialAccountsService, InstagramAdapter, XAdapter, TokenEncryptionService],
  exports: [SocialAccountsService],
})
export class SocialAccountsModule {}
