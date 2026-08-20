import { HttpException, HttpStatus, Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { PLAN_LIMITS, PlanLimits, isWithinLimit } from './plan-config';

/// Enforces per-plan resource limits (Phase 18) and reports current usage.
///
/// Gating throws HTTP 402 (Payment Required) with an actionable message when a
/// mutating action would exceed the org's plan — the caller (a connect/invite
/// endpoint) simply awaits the assert before proceeding. Reads are cheap
/// COUNTs; the org's planTier column is the source of truth for which limits
/// apply (kept in sync by billing webhooks).
@Injectable()
export class PlanLimitsService {
  constructor(private readonly prisma: PrismaService) {}

  async limitsFor(orgId: string): Promise<PlanLimits> {
    const org = await this.prisma.organization.findUnique({
      where: { id: orgId },
      select: { planTier: true },
    });
    return PLAN_LIMITS[org?.planTier ?? 'free'];
  }

  /// Current usage counts for the billing page's "usage vs limit" display.
  async usage(orgId: string): Promise<{
    socialAccounts: number;
    teamMembers: number;
    aiCreditsUsed: number;
  }> {
    const [socialAccounts, teamMembers, aiCreditsUsed] = await Promise.all([
      this.prisma.socialAccount.count({ where: { orgId } }),
      this.prisma.user.count({ where: { orgId } }),
      this.prisma.aIUsageLog.count({
        where: { orgId, createdAt: { gte: startOfMonth() } },
      }),
    ]);
    return { socialAccounts, teamMembers, aiCreditsUsed };
  }

  /// Throws 402 if connecting another social account would exceed the plan.
  async assertCanConnectSocialAccount(orgId: string): Promise<void> {
    const limits = await this.limitsFor(orgId);
    const count = await this.prisma.socialAccount.count({ where: { orgId } });
    if (!isWithinLimit(count, limits.maxSocialAccounts)) {
      throw this.overLimit(
        `Your plan allows ${limits.maxSocialAccounts} connected accounts. ` +
          `Upgrade to connect more.`,
      );
    }
  }

  /// Throws 402 if adding another member (invite/accept) would exceed the plan.
  /// `pendingInvites` are counted toward the seat cap so an org can't oversubscribe
  /// by queuing invites.
  async assertCanAddTeamMember(orgId: string): Promise<void> {
    const limits = await this.limitsFor(orgId);
    const [members, pendingInvites] = await Promise.all([
      this.prisma.user.count({ where: { orgId } }),
      this.prisma.invite.count({ where: { orgId, status: 'pending' } }),
    ]);
    if (!isWithinLimit(members + pendingInvites, limits.maxTeamMembers)) {
      throw this.overLimit(
        `Your plan allows ${limits.maxTeamMembers} team members. ` +
          `Upgrade to add more.`,
      );
    }
  }

  private overLimit(message: string): HttpException {
    return new HttpException(
      { statusCode: HttpStatus.PAYMENT_REQUIRED, message, error: 'PlanLimitReached' },
      HttpStatus.PAYMENT_REQUIRED,
    );
  }
}

/// First instant of the current UTC month — the AI-credit metering window.
function startOfMonth(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
}
