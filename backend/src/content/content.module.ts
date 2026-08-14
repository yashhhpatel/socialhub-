import { Module } from '@nestjs/common';

import { CloudinaryService } from '../media/cloudinary.service';
import { VideoProcessingService } from '../media/video-processing.service';
import { FacebookAdapter } from '../social-accounts/adapters/facebook.adapter';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { LinkedInAdapter } from '../social-accounts/adapters/linkedin.adapter';
import { ThreadsAdapter } from '../social-accounts/adapters/threads.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import { ApprovalController } from './approval.controller';
import { ApprovalService } from './approval.service';
import { ContentController } from './content.controller';
import { ContentService } from './content.service';
import { VariantGeneratorService } from './variant-generator.service';

/**
 * Adapters are provided directly rather than by importing
 * SocialAccountsModule, because that module exports only
 * SocialAccountsService — and variant generation needs the adapters'
 * capabilities() metadata, not the OAuth orchestration around them.
 * Adapters are stateless (capabilities() is documented as synchronous and
 * side-effect-free), so a second instance costs nothing and avoids
 * widening SocialAccountsModule's public surface just for this.
 */
@Module({
  controllers: [ContentController, ApprovalController],
  providers: [
    ApprovalService,
    ContentService,
    CloudinaryService,
    VideoProcessingService,
    VariantGeneratorService,
    InstagramAdapter,
    XAdapter,
    FacebookAdapter,
    ThreadsAdapter,
    LinkedInAdapter,
  ],
  exports: [ContentService],
})
export class ContentModule {}
