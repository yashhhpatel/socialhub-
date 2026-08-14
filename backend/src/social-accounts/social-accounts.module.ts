import { Module } from '@nestjs/common';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { FacebookAdapter } from './adapters/facebook.adapter';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { LinkedInAdapter } from './adapters/linkedin.adapter';
import { ThreadsAdapter } from './adapters/threads.adapter';
import { XAdapter } from './adapters/x.adapter';
import { SocialAccountsController } from './social-accounts.controller';
import { SocialAccountsService } from './social-accounts.service';

@Module({
  controllers: [SocialAccountsController],
  providers: [
    SocialAccountsService,
    InstagramAdapter,
    XAdapter,
    FacebookAdapter,
    ThreadsAdapter,
    LinkedInAdapter,
    TokenEncryptionService,
  ],
  exports: [SocialAccountsService],
})
export class SocialAccountsModule {}
