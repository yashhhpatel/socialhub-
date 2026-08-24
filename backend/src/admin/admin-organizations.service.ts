import { Injectable, NotFoundException } from '@nestjs/common';
import { PublishJobStatus, SocialAccountStatus } from '@prisma/client';

import { PlanLimitsService } from '../billing/plan-limits.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  AdminOrgDetailDto,
  AdminOrgListDto,
} from './dto/admin-organizations.dto';

const MAX_LIMIT = 100;

/**
 * Cross-tenant organization views for the admin panel (Phase 21.3). Read-only;
 * reuses PlanLimitsService for usage-vs-limits so the numbers match the billing
 * page. No secrets are selected.
 */
@Injectable()
export class AdminOrganizationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly planLimits: PlanLimitsService,
  ) {}

  async list(params: {
    search?: string;
    page?: number;
    limit?: number;
  }): Promise<AdminOrgListDto> {
    const page = Math.max(1, params.page ?? 1);
    const limit = Math.min(MAX_LIMIT, Math.max(1, params.limit ?? 20));
    const search = params.search?.trim();

    const where = search
      ? { name: { contains: search, mode: 'insensitive' as const } }
      : {};

    const [total, rows] = await Promise.all([
      this.prisma.organization.count({ where }),
      this.prisma.organization.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          name: true,
          planTier: true,
          createdAt: true,
          subscription: { select: { status: true } },
          _count: { select: { users: true, socialAccounts: true } },
        },
      }),
    ]);

    return {
      total,
      page,
      limit,
      data: rows.map((o) => ({
        id: o.id,
        name: o.name,
        planTier: o.planTier,
        subscriptionStatus: o.subscription?.status ?? null,
        memberCount: o._count.users,
        socialAccountCount: o._count.socialAccounts,
        createdAt: o.createdAt,
      })),
    };
  }

  async detail(orgId: string): Promise<AdminOrgDetailDto> {
    const org = await this.prisma.organization.findUnique({
      where: { id: orgId },
      select: {
        id: true,
        name: true,
        planTier: true,
        status: true,
        requiresApproval: true,
        createdAt: true,
        subscription: { select: { status: true, currentPeriodEnd: true } },
        users: {
          orderBy: { createdAt: 'asc' },
          select: {
            id: true,
            email: true,
            role: true,
            emailVerifiedAt: true,
            mfaEnabled: true,
            isPlatformAdmin: true,
          },
        },
      },
    });
    if (!org) throw new NotFoundException('Organization not found.');

    const [usage, limits, connectedAccounts, drafts, scheduled, published] =
      await Promise.all([
        this.planLimits.usage(orgId),
        this.planLimits.limitsFor(orgId),
        this.prisma.socialAccount.count({
          where: { orgId, status: SocialAccountStatus.connected },
        }),
        this.prisma.contentAsset.count({
          where: { orgId, approvalStatus: 'draft' },
        }),
        this.prisma.publishJob.count({
          where: {
            socialAccount: { orgId },
            status: {
              in: [PublishJobStatus.scheduled, PublishJobStatus.queued],
            },
          },
        }),
        this.prisma.publishJob.count({
          where: { socialAccount: { orgId }, status: PublishJobStatus.published },
        }),
      ]);

    return {
      id: org.id,
      name: org.name,
      planTier: org.planTier,
      status: org.status,
      requiresApproval: org.requiresApproval,
      subscriptionStatus: org.subscription?.status ?? null,
      currentPeriodEnd: org.subscription?.currentPeriodEnd ?? null,
      createdAt: org.createdAt,
      members: org.users.map((u) => ({
        id: u.id,
        email: u.email,
        role: u.role,
        emailVerified: u.emailVerifiedAt !== null,
        mfaEnabled: u.mfaEnabled,
        isPlatformAdmin: u.isPlatformAdmin,
      })),
      usage: {
        socialAccounts: usage.socialAccounts,
        teamMembers: usage.teamMembers,
        aiCreditsUsed: usage.aiCreditsUsed,
      },
      limits: {
        maxSocialAccounts: limits.maxSocialAccounts,
        maxTeamMembers: limits.maxTeamMembers,
        aiCreditsPerMonth: limits.aiCreditsPerMonth,
        maxScheduledPosts: limits.maxScheduledPosts,
      },
      activity: {
        connectedAccounts,
        drafts,
        scheduledPosts: scheduled,
        publishedPosts: published,
      },
    };
  }
}
