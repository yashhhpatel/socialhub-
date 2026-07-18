import { Module } from '@nestjs/common';

import { CloudinaryService } from '../media/cloudinary.service';
import { ContentController } from './content.controller';
import { ContentService } from './content.service';

@Module({
  controllers: [ContentController],
  providers: [ContentService, CloudinaryService],
  exports: [ContentService],
})
export class ContentModule {}
