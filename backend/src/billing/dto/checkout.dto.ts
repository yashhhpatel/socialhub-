import { PlanTier } from '@prisma/client';
import { IsEnum } from 'class-validator';

/// Body for POST /billing/checkout — which plan to subscribe to.
export class CheckoutDto {
  @IsEnum(PlanTier, { message: 'Choose a valid plan.' })
  tier: PlanTier;
}
