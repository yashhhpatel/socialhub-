import { HttpException, HttpStatus } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { PlanLimitsService } from './plan-limits.service';

describe('PlanLimitsService', () => {
  let service: PlanLimitsService;
  let prisma: {
    organization: { findUnique: jest.Mock };
    socialAccount: { count: jest.Mock };
    user: { count: jest.Mock };
    invite: { count: jest.Mock };
    aIUsageLog: { count: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      organization: { findUnique: jest.fn() },
      socialAccount: { count: jest.fn() },
      user: { count: jest.fn() },
      invite: { count: jest.fn() },
      aIUsageLog: { count: jest.fn() },
    };
    service = new PlanLimitsService(prisma as unknown as PrismaService);
  });

  const onPlan = (tier: string) =>
    prisma.organization.findUnique.mockResolvedValue({ planTier: tier });

  describe('assertCanConnectSocialAccount', () => {
    it('allows connecting below the free cap (2)', async () => {
      onPlan('free');
      prisma.socialAccount.count.mockResolvedValue(1);
      await expect(
        service.assertCanConnectSocialAccount('org1'),
      ).resolves.toBeUndefined();
    });

    it('blocks with 402 at the free cap', async () => {
      onPlan('free');
      prisma.socialAccount.count.mockResolvedValue(2);
      let status: number | undefined;
      try {
        await service.assertCanConnectSocialAccount('org1');
        fail('expected a plan-limit error');
      } catch (e) {
        expect(e).toBeInstanceOf(HttpException);
        status = (e as HttpException).getStatus();
      }
      expect(status).toBe(HttpStatus.PAYMENT_REQUIRED);
    });

    it('never blocks on enterprise (unlimited)', async () => {
      onPlan('enterprise');
      prisma.socialAccount.count.mockResolvedValue(9999);
      await expect(
        service.assertCanConnectSocialAccount('org1'),
      ).resolves.toBeUndefined();
    });
  });

  describe('assertCanAddTeamMember', () => {
    it('counts members + pending invites against the seat cap', async () => {
      onPlan('starter'); // maxTeamMembers 5
      prisma.user.count.mockResolvedValue(3);
      prisma.invite.count.mockResolvedValue(2); // 3 + 2 == 5 → at cap
      await expect(service.assertCanAddTeamMember('org1')).rejects.toBeInstanceOf(
        HttpException,
      );
    });

    it('allows when members + invites are below the cap', async () => {
      onPlan('starter');
      prisma.user.count.mockResolvedValue(2);
      prisma.invite.count.mockResolvedValue(1);
      await expect(
        service.assertCanAddTeamMember('org1'),
      ).resolves.toBeUndefined();
    });
  });

  describe('usage', () => {
    it('returns the three metered counts', async () => {
      prisma.socialAccount.count.mockResolvedValue(4);
      prisma.user.count.mockResolvedValue(6);
      prisma.aIUsageLog.count.mockResolvedValue(120);
      await expect(service.usage('org1')).resolves.toEqual({
        socialAccounts: 4,
        teamMembers: 6,
        aiCreditsUsed: 120,
      });
    });
  });

  it('defaults to the free plan for an unknown org', async () => {
    prisma.organization.findUnique.mockResolvedValue(null);
    await expect(service.limitsFor('ghost')).resolves.toMatchObject({
      maxSocialAccounts: 2,
    });
  });
});
