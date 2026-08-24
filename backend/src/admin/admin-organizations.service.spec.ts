import { NotFoundException } from '@nestjs/common';

import { PlanLimitsService } from '../billing/plan-limits.service';
import { PrismaService } from '../prisma/prisma.service';
import { AdminOrganizationsService } from './admin-organizations.service';

describe('AdminOrganizationsService', () => {
  let service: AdminOrganizationsService;
  let prisma: {
    organization: { count: jest.Mock; findMany: jest.Mock; findUnique: jest.Mock };
    socialAccount: { count: jest.Mock };
    contentAsset: { count: jest.Mock };
    publishJob: { count: jest.Mock };
  };
  let planLimits: { usage: jest.Mock; limitsFor: jest.Mock };

  beforeEach(() => {
    prisma = {
      organization: { count: jest.fn(), findMany: jest.fn(), findUnique: jest.fn() },
      socialAccount: { count: jest.fn().mockResolvedValue(0) },
      contentAsset: { count: jest.fn().mockResolvedValue(0) },
      publishJob: { count: jest.fn().mockResolvedValue(0) },
    };
    planLimits = {
      usage: jest.fn().mockResolvedValue({
        socialAccounts: 1,
        teamMembers: 2,
        aiCreditsUsed: 3,
      }),
      limitsFor: jest.fn().mockResolvedValue({
        maxSocialAccounts: 2,
        maxTeamMembers: 2,
        aiCreditsPerMonth: 50,
        maxScheduledPosts: 10,
      }),
    };
    service = new AdminOrganizationsService(
      prisma as unknown as PrismaService,
      planLimits as unknown as PlanLimitsService,
    );
  });

  describe('list', () => {
    it('paginates, maps counts, and clamps the limit', async () => {
      prisma.organization.count.mockResolvedValue(42);
      prisma.organization.findMany.mockResolvedValue([
        {
          id: 'o1',
          name: 'Acme',
          planTier: 'free',
          createdAt: new Date(0),
          subscription: { status: 'active' },
          _count: { users: 3, socialAccounts: 2 },
        },
      ]);

      const res = await service.list({ page: 2, limit: 500, search: '  ac ' });

      expect(res.total).toBe(42);
      expect(res.page).toBe(2);
      expect(res.limit).toBe(100); // clamped to MAX_LIMIT
      expect(res.data[0]).toEqual(
        expect.objectContaining({
          id: 'o1',
          memberCount: 3,
          socialAccountCount: 2,
          subscriptionStatus: 'active',
        }),
      );
      const findArgs = prisma.organization.findMany.mock.calls[0][0];
      expect(findArgs.where.name.contains).toBe('ac'); // trimmed
      expect(findArgs.skip).toBe(100); // (page 2 - 1) * clamped limit 100
    });

    it('returns null subscription status when there is no subscription', async () => {
      prisma.organization.count.mockResolvedValue(1);
      prisma.organization.findMany.mockResolvedValue([
        {
          id: 'o1',
          name: 'Solo',
          planTier: 'free',
          createdAt: new Date(0),
          subscription: null,
          _count: { users: 1, socialAccounts: 0 },
        },
      ]);
      const res = await service.list({});
      expect(res.data[0].subscriptionStatus).toBeNull();
    });
  });

  describe('detail', () => {
    it('404s when the org does not exist', async () => {
      prisma.organization.findUnique.mockResolvedValue(null);
      await expect(service.detail('nope')).rejects.toBeInstanceOf(NotFoundException);
    });

    it('returns members (no secrets), usage/limits, and activity', async () => {
      prisma.organization.findUnique.mockResolvedValue({
        id: 'o1',
        name: 'Acme',
        planTier: 'pro',
        requiresApproval: false,
        createdAt: new Date(0),
        subscription: { status: 'active', currentPeriodEnd: new Date(1) },
        users: [
          {
            id: 'u1',
            email: 'a@b.com',
            role: 'owner',
            emailVerifiedAt: new Date(),
            mfaEnabled: true,
            isPlatformAdmin: false,
          },
        ],
      });
      prisma.socialAccount.count.mockResolvedValue(2);
      prisma.contentAsset.count.mockResolvedValue(4);
      prisma.publishJob.count
        .mockResolvedValueOnce(1) // scheduled
        .mockResolvedValueOnce(9); // published

      const d = await service.detail('o1');

      expect(d.members[0]).toEqual(
        expect.objectContaining({ email: 'a@b.com', emailVerified: true }),
      );
      // No secret fields leaked.
      expect(JSON.stringify(d)).not.toMatch(/passwordHash|mfaSecret|TokenEnc/);
      expect(d.usage.teamMembers).toBe(2);
      expect(d.limits.aiCreditsPerMonth).toBe(50);
      expect(d.activity.connectedAccounts).toBe(2);
      expect(d.activity.publishedPosts).toBe(9);
    });
  });
});
