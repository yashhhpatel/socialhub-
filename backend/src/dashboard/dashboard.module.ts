import { Module } from '@nestjs/common';

import { BillingModule } from '../billing/billing.module';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';

/// Overview dashboard aggregation (Phase 20). Imports BillingModule to reuse
/// PlanLimitsService for AI-credit usage/limits (single source of truth).
/// PrismaService is global.
@Module({
  imports: [BillingModule],
  controllers: [DashboardController],
  providers: [DashboardService],
})
export class DashboardModule {}
