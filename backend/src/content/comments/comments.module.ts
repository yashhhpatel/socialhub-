import { Module } from '@nestjs/common';

import { ContentModule } from '../content.module';
import { CommentsController } from './comments.controller';
import { CommentsService } from './comments.service';

/**
 * Comments (Milestone 13.1). Imports ContentModule for ContentService,
 * which does the org-scoped asset lookup every comment operation depends on.
 */
@Module({
  imports: [ContentModule],
  controllers: [CommentsController],
  providers: [CommentsService],
  exports: [CommentsService],
})
export class CommentsModule {}
