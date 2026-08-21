import { Module } from '@nestjs/common';

import { CloudinaryService } from './cloudinary.service';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';
import { VideoProcessingService } from './video-processing.service';

/// Persistent media library (Phase 19). Cloudinary + video services are
/// stateless, so providing them here (as ContentModule also does) is
/// harmless and keeps this module self-contained. PrismaService is global.
@Module({
  controllers: [MediaController],
  providers: [MediaService, CloudinaryService, VideoProcessingService],
  exports: [MediaService],
})
export class MediaModule {}
