import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { Platform } from '@prisma/client';

import { AuthModule } from '../auth/auth.module';
import { PUBLISH_QUEUES } from '../publishing/publish-queue.constants';
import { TOKEN_REFRESH_QUEUE } from '../social-accounts/token-refresh.constants';
import { BillingModule } from '../billing/billing.module';
import { PublishingModule } from '../publishing/publishing.module';
import { SocialAccountsModule } from '../social-accounts/social-accounts.module';
import { AdminController } from './admin.controller';
import { AdminOrganizationsService } from './admin-organizations.service';
import { AdminOverviewService } from './admin-overview.service';
import { AdminPublishingService } from './admin-publishing.service';
import { AdminAuditService } from './admin-audit.service';
import { AdminBillingService } from './admin-billing.service';
import { AdminComplianceService } from './admin-compliance.service';
import { AdminSystemService } from './admin-system.service';
import { AdminSocialAccountsService } from './admin-social-accounts.service';
import { AdminUsersService } from './admin-users.service';
import { PlatformAdminGuard } from './guards/platform-admin.guard';

/**
 * Platform Admin Panel (Phase 21). Cross-tenant operator surface, gated by
 * PlatformAdminGuard. Imports BillingModule (PlanLimitsService) and AuthModule
 * (AccountService for the safe user actions). PrismaService is global.
 */
@Module({
  imports: [
    BillingModule,
    AuthModule,
    SocialAccountsModule,
    PublishingModule,
    // Register the same queues so the system monitor can read their job counts
    // (shared Redis connection from the global QueueModule).
    BullModule.registerQueue(
      { name: PUBLISH_QUEUES[Platform.instagram] },
      { name: PUBLISH_QUEUES[Platform.x] },
      { name: PUBLISH_QUEUES[Platform.facebook] },
      { name: PUBLISH_QUEUES[Platform.threads] },
      { name: PUBLISH_QUEUES[Platform.linkedin] },
      { name: TOKEN_REFRESH_QUEUE },
    ),
  ],
  controllers: [AdminController],
  providers: [
    PlatformAdminGuard,
    AdminOverviewService,
    AdminOrganizationsService,
    AdminUsersService,
    AdminSocialAccountsService,
    AdminBillingService,
    AdminPublishingService,
    AdminAuditService,
    AdminComplianceService,
    AdminSystemService,
  ],
})
export class AdminModule {}
