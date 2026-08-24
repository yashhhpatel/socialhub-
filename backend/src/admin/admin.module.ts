import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { BillingModule } from '../billing/billing.module';
import { PublishingModule } from '../publishing/publishing.module';
import { SocialAccountsModule } from '../social-accounts/social-accounts.module';
import { AdminController } from './admin.controller';
import { AdminOrganizationsService } from './admin-organizations.service';
import { AdminOverviewService } from './admin-overview.service';
import { AdminPublishingService } from './admin-publishing.service';
import { AdminBillingService } from './admin-billing.service';
import { AdminSocialAccountsService } from './admin-social-accounts.service';
import { AdminUsersService } from './admin-users.service';
import { PlatformAdminGuard } from './guards/platform-admin.guard';

/**
 * Platform Admin Panel (Phase 21). Cross-tenant operator surface, gated by
 * PlatformAdminGuard. Imports BillingModule (PlanLimitsService) and AuthModule
 * (AccountService for the safe user actions). PrismaService is global.
 */
@Module({
  imports: [BillingModule, AuthModule, SocialAccountsModule, PublishingModule],
  controllers: [AdminController],
  providers: [
    PlatformAdminGuard,
    AdminOverviewService,
    AdminOrganizationsService,
    AdminUsersService,
    AdminSocialAccountsService,
    AdminBillingService,
    AdminPublishingService,
  ],
})
export class AdminModule {}
