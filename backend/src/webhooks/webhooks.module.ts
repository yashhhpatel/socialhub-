import { Module } from '@nestjs/common';

import { WebhooksController } from './webhooks.controller';
import { WebhooksService } from './webhooks.service';

/// Inbound platform webhooks (Phase 20). PrismaService is global; ConfigService
/// comes from the global ConfigModule.
@Module({
  controllers: [WebhooksController],
  providers: [WebhooksService],
})
export class WebhooksModule {}
