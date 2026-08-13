import { PlanTier } from '@prisma/client';

/**
 * Length of the quota window, in days (Milestone 5.2).
 *
 * ROLLING, not calendar-month. docs/SocialHub_Database_Design.md describes
 * the ai_usage_log index as serving "usage in the last 30 days", and the
 * `@@index([orgId, createdAt])` it specifies is exactly the shape a rolling
 * range scan wants. A calendar month would also mean every org's allowance
 * resets at midnight on the 1st, concentrating the month's heaviest AI load
 * into a single hour — a rolling window spreads the same allowance evenly.
 */
export const AI_QUOTA_WINDOW_DAYS = 30;

/**
 * Generations allowed per org per rolling window, by plan tier.
 *
 * Counted per GENERATION, not per token. Tokens are recorded on each
 * AIUsageLog row (and Phase 5's note in schema.prisma explains why), but
 * billing by token would make the limit unpredictable for the user — two
 * captions for the same design could cost wildly different amounts of
 * quota depending on how much text the model happened to emit. A user can
 * reason about "25 generations left" in a way they cannot about tokens.
 *
 * These numbers are a starting point, not a commercial commitment — no
 * pricing doc exists yet to source them from. They are deliberately shaped
 * so `free` is enough to evaluate the feature and not enough to run a
 * business on. Revisit when Phase 12 adds four more AI features drawing on
 * the same allowance.
 */
export const AI_QUOTA_PER_WINDOW: Record<PlanTier, number> = {
  free: 25,
  starter: 250,
  pro: 2_000,
  enterprise: 25_000,
};

/**
 * Resolves an org's allowance, or null if the tier has no entry.
 *
 * The Record above is exhaustive over PlanTier at compile time, so null is
 * unreachable through normal code. It becomes reachable the moment someone
 * adds a value to the PlanTier enum and migrates the database without
 * updating this file — at which point the honest answer is "this tier's
 * allowance is undefined", and the caller must fail closed rather than
 * treat `undefined` as an unlimited budget against a paid API.
 */
export function aiQuotaFor(tier: PlanTier): number | null {
  const quota = AI_QUOTA_PER_WINDOW[tier] as number | undefined;
  return typeof quota === 'number' ? quota : null;
}
