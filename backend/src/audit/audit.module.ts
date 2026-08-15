import { Module } from '@nestjs/common';

import { AuditController } from './audit.controller';
import { AuditService } from './audit.service';

/**
 * Audit trail read side (Milestone 15.2). The WRITE side is the global
 * AuditLogInterceptor (registered in app.module), so it isn't a provider
 * here.
 */
@Module({
  controllers: [AuditController],
  providers: [AuditService],
})
export class AuditModule {}
