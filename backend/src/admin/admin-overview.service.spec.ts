import { PrismaService } from '../prisma/prisma.service';
import { AdminOverviewService } from './admin-overview.service';

describe('AdminOverviewService', () => {
  let service: AdminOverviewService;
  let prisma: {
    organization: { count: jest.Mock; groupBy: jest.Mock };
    user: { count: jest.Mock };
    socialAccount: { count: jest.Mock };
    publishJob: { count: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      organization: { count: jest.fn(), groupBy: jest.fn() },
      user: { count: jest.fn() },
      socialAccount: { count: jest.fn() },
      publishJob: { count: jest.fn() },
    };
    prisma.organization.groupBy.mockResolvedValue([
      { planTier: 'free', _count: { _all: 3 } },
      { planTier: 'pro', _count: { _all: 1 } },
    ]);
    service = new AdminOverviewService(prisma as unknown as PrismaService);
  });

  it('aggregates cross-tenant KPIs and computes the failure rate', async () => {
    // Order matters — mirrors the Promise.all sequence in the service.
    prisma.organization.count
      .mockResolvedValueOnce(4) // totalOrganizations
      .mockResolvedValueOnce(2) // newOrganizations30d
      .mockResolvedValueOnce(3); // activeOrganizations
    prisma.user.count
      .mockResolvedValueOnce(10) // totalUsers
      .mockResolvedValueOnce(5) // newUsers30d
      .mockResolvedValueOnce(2) // unverifiedUsers
      .mockResolvedValueOnce(1); // mfaEnabledUsers
    prisma.socialAccount.count
      .mockResolvedValueOnce(6) // connectedAccounts
      .mockResolvedValueOnce(2); // accountsNeedingReconnect
    prisma.publishJob.count
      .mockResolvedValueOnce(30) // publishedPosts
      .mockResolvedValueOnce(10); // failedPosts

    const o = await service.overview();

    expect(o.totalOrganizations).toBe(4);
    expect(o.totalUsers).toBe(10);
    expect(o.newOrganizations30d).toBe(2);
    expect(o.activeOrganizations).toBe(3);
    expect(o.connectedAccounts).toBe(6);
    expect(o.accountsNeedingReconnect).toBe(2);
    expect(o.publishedPosts).toBe(30);
    expect(o.failedPosts).toBe(10);
    expect(o.publishFailureRate).toBeCloseTo(0.25); // 10 / 40
    expect(o.unverifiedUsers).toBe(2);
    expect(o.mfaEnabledUsers).toBe(1);
  });

  it('lists every plan tier (0 when none) and 0 failure rate with no jobs', async () => {
    prisma.organization.count.mockResolvedValue(0);
    prisma.user.count.mockResolvedValue(0);
    prisma.socialAccount.count.mockResolvedValue(0);
    prisma.publishJob.count.mockResolvedValue(0);

    const o = await service.overview();

    expect(o.publishFailureRate).toBe(0); // no terminal jobs → no divide-by-zero
    const tiers = o.planDistribution.map((p) => p.tier);
    expect(tiers).toEqual(
      expect.arrayContaining(['free', 'starter', 'pro', 'enterprise']),
    );
    const free = o.planDistribution.find((p) => p.tier === 'free');
    expect(free?.count).toBe(3); // from groupBy mock
    const starter = o.planDistribution.find((p) => p.tier === 'starter');
    expect(starter?.count).toBe(0); // absent from groupBy → 0
  });
});
