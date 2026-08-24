import { Module } from '@nestjs/common';

import { AdminController } from './admin.controller';
import { PlatformAdminGuard } from './guards/platform-admin.guard';

/**
 * Platform Admin Panel (Phase 21). Cross-tenant operator surface, gated by
 * PlatformAdminGuard. PrismaService is global; feature services from other
 * modules are imported here as milestones add them.
 */
@Module({
  controllers: [AdminController],
  providers: [PlatformAdminGuard],
})
export class AdminModule {}
