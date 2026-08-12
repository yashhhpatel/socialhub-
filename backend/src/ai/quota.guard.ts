import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { PrismaService } from '../prisma/prisma.service';
import { AI_QUOTA_WINDOW_DAYS, aiQuotaFor } from './constants/ai-quota';

interface AuthenticatedRequest extends Request {
  user?: { userId: string; email: string; role: UserRole; orgId: string };
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Enforces an org's AI allowance before a generation runs (Milestone 5.2).
 *
 * Reads exactly what AiGatewayService writes: one AIUsageLog row per
 * successful generation. That pairing is the whole design — because the
 * gateway logs only on success, a provider outage cannot burn a customer's
 * allowance, and because it logs centrally, every AI feature Phase 12 adds
 * is metered by this guard without touching it.
 *
 * A GUARD, NOT A SERVICE CALL, and specifically a guard that runs BEFORE
 * the work: the check has to happen before tokens are spent, and a guard is
 * the only layer that sees the request early enough. The cost is that it
 * cannot be transactional with the write it's protecting — two concurrent
 * requests at the boundary can both observe `count == limit - 1` and both
 * proceed, overshooting by one. That is accepted deliberately: the
 * alternative is serializing every AI request behind a lock to defend a
 * soft monthly allowance, which trades real latency for an off-by-one on a
 * number the business rounds anyway.
 *
 * MUST run after JwtAuthGuard (@UseGuards(JwtAuthGuard, QuotaGuard)) — it
 * reads `request.user`, which only JwtAuthGuard's strategy populates.
 */
@Injectable()
export class QuotaGuard implements CanActivate {
  private readonly logger = new Logger(QuotaGuard.name);

  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const user = request.user;

    // Same reasoning as RolesGuard: no user means JwtAuthGuard didn't run
    // first, or let an unauthenticated request through — fail closed.
    if (!user) {
      return false;
    }

    const organization = await this.prisma.organization.findUnique({
      where: { id: user.orgId },
      select: { planTier: true },
    });

    // A valid JWT naming an org that no longer exists. Nothing to meter
    // against, so nothing gets spent.
    if (!organization) {
      return false;
    }

    const limit = aiQuotaFor(organization.planTier);
    if (limit === null) {
      // An unrecognized tier is a deployment mistake, not a user error —
      // log it loudly, but still refuse rather than defaulting to
      // unlimited spend against a paid API. See aiQuotaFor.
      this.logger.error(
        `No AI quota configured for plan tier "${organization.planTier}" ` +
          `(org ${user.orgId}) — denying the request. Add it to AI_QUOTA_PER_WINDOW.`,
      );
      return false;
    }

    const windowStart = new Date(Date.now() - AI_QUOTA_WINDOW_DAYS * MS_PER_DAY);
    const used = await this.prisma.aIUsageLog.count({
      where: { orgId: user.orgId, createdAt: { gte: windowStart } },
    });

    if (used < limit) {
      return true;
    }

    throw new HttpException(
      {
        statusCode: HttpStatus.TOO_MANY_REQUESTS,
        error: 'Too Many Requests',
        message:
          `Your organization has used all ${limit} AI generations included in ` +
          `its ${organization.planTier} plan for the last ${AI_QUOTA_WINDOW_DAYS} days.`,
        resetAt: (await this.resolveResetAt(user.orgId, used, limit)).toISOString(),
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }

  /**
   * When the org's next generation becomes possible.
   *
   * In a rolling window, allowance returns as old rows age out rather than
   * all at once. With `used` rows in the window and a limit of `limit`, the
   * count first drops below the limit when the (used - limit + 1)-th oldest
   * row leaves it — so that row's timestamp plus the window length is the
   * answer. Skipping `used - limit` rows selects exactly that one.
   *
   * The skip matters for the case `used > limit`, which happens whenever a
   * plan is downgraded (or these constants are lowered) while usage is
   * already above the new allowance. Naively using the single oldest row
   * would promise a reset at a time when the org would still be over.
   */
  private async resolveResetAt(
    orgId: string,
    used: number,
    limit: number,
  ): Promise<Date> {
    const windowStart = new Date(Date.now() - AI_QUOTA_WINDOW_DAYS * MS_PER_DAY);

    const [decidingRow] = await this.prisma.aIUsageLog.findMany({
      where: { orgId, createdAt: { gte: windowStart } },
      orderBy: { createdAt: 'asc' },
      skip: used - limit,
      take: 1,
      select: { createdAt: true },
    });

    // Only reachable if rows aged out between the count above and this
    // query. A full window from now is the safe direction to be wrong in:
    // it never tells the user to retry sooner than they actually can.
    if (!decidingRow) {
      return new Date(Date.now() + AI_QUOTA_WINDOW_DAYS * MS_PER_DAY);
    }

    return new Date(
      decidingRow.createdAt.getTime() + AI_QUOTA_WINDOW_DAYS * MS_PER_DAY,
    );
  }
}
