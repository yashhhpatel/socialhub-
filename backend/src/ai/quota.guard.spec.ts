import { ExecutionContext, HttpException, HttpStatus } from '@nestjs/common';
import { PlanTier, UserRole } from '@prisma/client';

import { AI_QUOTA_PER_WINDOW, AI_QUOTA_WINDOW_DAYS } from './constants/ai-quota';
import { QuotaGuard } from './quota.guard';

const MS_PER_DAY = 24 * 60 * 60 * 1000;

function makeContext(
  user: { orgId: string; role: UserRole } | undefined,
): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
    getHandler: () => ({}),
    getClass: () => ({}),
  } as unknown as ExecutionContext;
}

const AUTHED = { orgId: 'org_1', role: UserRole.owner };

describe('QuotaGuard', () => {
  let prisma: {
    organization: { findUnique: jest.Mock };
    aIUsageLog: { count: jest.Mock; findMany: jest.Mock };
  };

  /** Builds the guard over a stubbed Prisma — these tests never touch a database. */
  function build(): QuotaGuard {
    return new QuotaGuard(prisma as never);
  }

  /** Fixes the org's tier and how many generations it has already used. */
  function given(options: {
    planTier?: PlanTier | null;
    used?: number;
    oldestInWindow?: Date;
  }) {
    prisma.organization.findUnique.mockResolvedValue(
      options.planTier === null ? null : { planTier: options.planTier ?? PlanTier.free },
    );
    prisma.aIUsageLog.count.mockResolvedValue(options.used ?? 0);
    prisma.aIUsageLog.findMany.mockResolvedValue(
      options.oldestInWindow ? [{ createdAt: options.oldestInWindow }] : [],
    );
  }

  /** Runs the guard and returns the 429 payload, failing if it did not throw. */
  async function expect429(guard: QuotaGuard): Promise<Record<string, unknown>> {
    try {
      await guard.canActivate(makeContext(AUTHED));
    } catch (error) {
      expect(error).toBeInstanceOf(HttpException);
      const httpError = error as HttpException;
      expect(httpError.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
      return httpError.getResponse() as Record<string, unknown>;
    }
    throw new Error('Expected the guard to reject with 429, but it allowed the request.');
  }

  beforeEach(() => {
    prisma = {
      organization: { findUnique: jest.fn() },
      aIUsageLog: { count: jest.fn(), findMany: jest.fn() },
    };
  });

  describe('under quota', () => {
    it('allows a request when the org has used nothing', async () => {
      given({ planTier: PlanTier.free, used: 0 });
      await expect(build().canActivate(makeContext(AUTHED))).resolves.toBe(true);
    });

    it('allows the last request that still fits inside the allowance', async () => {
      // free = 25, so 24 used means this request is the 25th — still allowed.
      given({ planTier: PlanTier.free, used: AI_QUOTA_PER_WINDOW.free - 1 });
      await expect(build().canActivate(makeContext(AUTHED))).resolves.toBe(true);
    });

    it('meters against the caller\'s own org and the window, not all usage ever', async () => {
      given({ planTier: PlanTier.free, used: 1 });
      await build().canActivate(makeContext(AUTHED));

      const where = prisma.aIUsageLog.count.mock.calls[0][0].where;
      expect(where.orgId).toBe('org_1');

      // Window start must be ~30 days ago, not the epoch.
      const windowStart: Date = where.createdAt.gte;
      const daysAgo = (Date.now() - windowStart.getTime()) / MS_PER_DAY;
      expect(daysAgo).toBeCloseTo(AI_QUOTA_WINDOW_DAYS, 1);
    });

    it('gives a higher tier its larger allowance at the same usage level', async () => {
      // 500 generations is over `free` and `starter`, but well inside `pro`.
      given({ planTier: PlanTier.pro, used: 500 });
      await expect(build().canActivate(makeContext(AUTHED))).resolves.toBe(true);
    });
  });

  describe('at or over quota', () => {
    it('rejects with 429 once the allowance is exhausted', async () => {
      given({
        planTier: PlanTier.free,
        used: AI_QUOTA_PER_WINDOW.free,
        oldestInWindow: new Date(),
      });

      const body = await expect429(build());
      expect(body.statusCode).toBe(HttpStatus.TOO_MANY_REQUESTS);
      expect(body.message).toContain('25');
      expect(body.message).toContain('free');
    });

    it('includes a resetAt one window on from the row that frees the allowance', async () => {
      // Exactly at the limit: the oldest row in the window is the one whose
      // expiry drops usage back under it.
      const oldest = new Date('2026-08-01T09:00:00.000Z');
      given({
        planTier: PlanTier.free,
        used: AI_QUOTA_PER_WINDOW.free,
        oldestInWindow: oldest,
      });

      const body = await expect429(build());
      expect(body.resetAt).toBe(
        new Date(oldest.getTime() + AI_QUOTA_WINDOW_DAYS * MS_PER_DAY).toISOString(),
      );
    });

    it('skips past already-expired-by-downgrade rows when usage exceeds the limit', async () => {
      // A downgraded org: 30 rows used against a limit of 25. Usage only
      // falls under the limit once the 6th-oldest row ages out, so the guard
      // must skip the 5 older ones rather than promising the oldest.
      given({
        planTier: PlanTier.free,
        used: 30,
        oldestInWindow: new Date('2026-08-06T00:00:00.000Z'),
      });

      await expect429(build());

      expect(prisma.aIUsageLog.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 30 - AI_QUOTA_PER_WINDOW.free,
          take: 1,
          orderBy: { createdAt: 'asc' },
        }),
      );
    });

    it('still returns a usable resetAt if the deciding row aged out mid-check', async () => {
      given({
        planTier: PlanTier.free,
        used: AI_QUOTA_PER_WINDOW.free,
        // findMany returns nothing — the race described in resolveResetAt.
      });

      const body = await expect429(build());
      const resetAt = new Date(body.resetAt as string).getTime();
      // A full window from now: never sooner than the org can actually retry.
      expect((resetAt - Date.now()) / MS_PER_DAY).toBeCloseTo(AI_QUOTA_WINDOW_DAYS, 1);
    });

    it('does not run a generation it just rejected', async () => {
      given({
        planTier: PlanTier.free,
        used: AI_QUOTA_PER_WINDOW.free,
        oldestInWindow: new Date(),
      });
      await expect429(build());
      // The guard's only job is the verdict — it must not have written a
      // usage row of its own. Only AiGatewayService writes those.
      expect(prisma.aIUsageLog.count).toHaveBeenCalledTimes(1);
    });
  });

  describe('fails closed', () => {
    it('denies when no authenticated user is on the request', async () => {
      given({ planTier: PlanTier.free, used: 0 });
      await expect(build().canActivate(makeContext(undefined))).resolves.toBe(false);
      // Must not have gone looking for an org it has no id for.
      expect(prisma.organization.findUnique).not.toHaveBeenCalled();
    });

    it('denies when the token names an organization that no longer exists', async () => {
      given({ planTier: null });
      await expect(build().canActivate(makeContext(AUTHED))).resolves.toBe(false);
      expect(prisma.aIUsageLog.count).not.toHaveBeenCalled();
    });

    it('denies an unrecognized plan tier rather than treating it as unlimited', async () => {
      // A tier added to the enum and migrated, but never given an allowance.
      given({ planTier: 'ultra' as PlanTier, used: 0 });
      await expect(build().canActivate(makeContext(AUTHED))).resolves.toBe(false);
      expect(prisma.aIUsageLog.count).not.toHaveBeenCalled();
    });
  });

  describe('quota table', () => {
    it('defines a positive allowance for every plan tier', () => {
      for (const tier of Object.values(PlanTier)) {
        expect(AI_QUOTA_PER_WINDOW[tier]).toBeGreaterThan(0);
      }
    });

    it('never gives a cheaper tier more than a more expensive one', () => {
      const ascending: PlanTier[] = [
        PlanTier.free,
        PlanTier.starter,
        PlanTier.pro,
        PlanTier.enterprise,
      ];
      for (let i = 1; i < ascending.length; i++) {
        expect(AI_QUOTA_PER_WINDOW[ascending[i]]).toBeGreaterThan(
          AI_QUOTA_PER_WINDOW[ascending[i - 1]],
        );
      }
    });
  });
});
