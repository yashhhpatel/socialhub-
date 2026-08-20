import { PlanTier } from '@prisma/client';

/// Per-plan resource limits (Phase 18). `-1` means unlimited. These are the
/// single source of truth for plan-gating (see PlanLimitsService) and for the
/// usage display on the billing page.
export interface PlanLimits {
  maxSocialAccounts: number;
  maxTeamMembers: number;
  aiCreditsPerMonth: number;
  maxScheduledPosts: number;
}

export const PLAN_LIMITS: Record<PlanTier, PlanLimits> = {
  free: {
    maxSocialAccounts: 2,
    maxTeamMembers: 2,
    aiCreditsPerMonth: 50,
    maxScheduledPosts: 10,
  },
  starter: {
    maxSocialAccounts: 5,
    maxTeamMembers: 5,
    aiCreditsPerMonth: 500,
    maxScheduledPosts: 100,
  },
  pro: {
    maxSocialAccounts: 15,
    maxTeamMembers: 20,
    aiCreditsPerMonth: 5000,
    maxScheduledPosts: -1,
  },
  enterprise: {
    maxSocialAccounts: -1,
    maxTeamMembers: -1,
    aiCreditsPerMonth: -1,
    maxScheduledPosts: -1,
  },
};

/// Tiers that are actually purchasable via Stripe (free is the default, not a
/// checkout target). Each maps to a Stripe Price via an env var so the price
/// ids stay out of the codebase.
export const PURCHASABLE_TIERS: PlanTier[] = [
  PlanTier.starter,
  PlanTier.pro,
  PlanTier.enterprise,
];

/// Env var holding the Stripe Price id for a purchasable tier.
export function stripePriceEnvKey(tier: PlanTier): string {
  return `STRIPE_PRICE_${tier.toUpperCase()}`;
}

/// True when a resource count is within the plan's limit (`-1` = unlimited).
export function isWithinLimit(count: number, limit: number): boolean {
  return limit < 0 || count < limit;
}
