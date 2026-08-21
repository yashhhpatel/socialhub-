import { Module } from '@nestjs/common';

import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

/// In-app notifications (Phase 19). Exports [NotificationsService] so event
/// producers (publishing worker, invite acceptance) can emit notifications.
@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
