import { Module } from '@nestjs/common';

import { BillingModule } from '../billing/billing.module';
import { AdminController } from './admin.controller';
import { AdminOrganizationsService } from './admin-organizations.service';
import { AdminOverviewService } from './admin-overview.service';
import { PlatformAdminGuard } from './guards/platform-admin.guard';

/**
 * Platform Admin Panel (Phase 21). Cross-tenant operator surface, gated by
 * PlatformAdminGuard. Imports BillingModule to reuse PlanLimitsService (usage
 * vs limits). PrismaService is global.
 */
@Module({
  imports: [BillingModule],
  controllers: [AdminController],
  providers: [
    PlatformAdminGuard,
    AdminOverviewService,
    AdminOrganizationsService,
  ],
})
export class AdminModule {}
