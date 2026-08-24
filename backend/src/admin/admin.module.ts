import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { BillingModule } from '../billing/billing.module';
import { AdminController } from './admin.controller';
import { AdminOrganizationsService } from './admin-organizations.service';
import { AdminOverviewService } from './admin-overview.service';
import { AdminUsersService } from './admin-users.service';
import { PlatformAdminGuard } from './guards/platform-admin.guard';

/**
 * Platform Admin Panel (Phase 21). Cross-tenant operator surface, gated by
 * PlatformAdminGuard. Imports BillingModule (PlanLimitsService) and AuthModule
 * (AccountService for the safe user actions). PrismaService is global.
 */
@Module({
  imports: [BillingModule, AuthModule],
  controllers: [AdminController],
  providers: [
    PlatformAdminGuard,
    AdminOverviewService,
    AdminOrganizationsService,
    AdminUsersService,
  ],
})
export class AdminModule {}
