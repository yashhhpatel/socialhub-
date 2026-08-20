import { Module } from '@nestjs/common';

import { BillingController } from './billing.controller';
import { BillingService } from './billing.service';
import { PlanLimitsService } from './plan-limits.service';
import { StripeService } from './stripe.service';

/// Billing & monetization (Phase 18). Exports [PlanLimitsService] so other
/// feature modules (social accounts, invites) can enforce plan limits.
/// PrismaService and ConfigService come from their global modules.
@Module({
  controllers: [BillingController],
  providers: [BillingService, StripeService, PlanLimitsService],
  exports: [PlanLimitsService],
})
export class BillingModule {}
