import { PlanLimitsService } from '../billing/plan-limits.service';
import { PrismaService } from '../prisma/prisma.service';
import { DashboardService } from './dashboard.service';

describe('DashboardService', () => {
  let service: DashboardService;
  let prisma: {
    publishJob: { count: jest.Mock; findMany: jest.Mock };
    contentAsset: { count: jest.Mock; findMany: jest.Mock };
    socialAccount: { count: jest.Mock; findMany: jest.Mock };
  };
  let planLimits: { usage: jest.Mock; limitsFor: jest.Mock };

  beforeEach(() => {
    prisma = {
      publishJob: { count: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
      contentAsset: { count: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
      socialAccount: { count: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
    };
    planLimits = {
      usage: jest.fn().mockResolvedValue({
        socialAccounts: 2,
        teamMembers: 1,
        aiCreditsUsed: 42,
      }),
      limitsFor: jest.fn().mockResolvedValue({ aiCreditsPerMonth: 500 }),
    };
    // count() returns differ per call; queue them in call order.
    prisma.publishJob.count
      .mockResolvedValueOnce(3) // scheduled
      .mockResolvedValueOnce(17); // published
    prisma.contentAsset.count.mockResolvedValue(4); // drafts
    prisma.socialAccount.count.mockResolvedValue(2); // connected

    service = new DashboardService(
      prisma as unknown as PrismaService,
      planLimits as unknown as PlanLimitsService,
    );
  });

  it('returns org-scoped counts and AI credits from PlanLimitsService', async () => {
    const summary = await service.summary('org1');

    expect(summary.scheduledPosts).toBe(3);
    expect(summary.publishedPosts).toBe(17);
    expect(summary.drafts).toBe(4);
    expect(summary.connectedAccounts).toBe(2);
    expect(summary.aiCreditsUsed).toBe(42);
    expect(summary.aiCreditsTotal).toBe(500);
    expect(planLimits.usage).toHaveBeenCalledWith('org1');
  });

  it('scopes publish-job counts to the org via the social account', async () => {
    await service.summary('org1');
    const firstCall = prisma.publishJob.count.mock.calls[0][0];
    expect(firstCall.where.socialAccount).toEqual({ orgId: 'org1' });
  });

  it('scopes drafts and connected accounts to the org', async () => {
    await service.summary('org1');
    expect(prisma.contentAsset.count).toHaveBeenCalledWith({
      where: { orgId: 'org1', approvalStatus: 'draft' },
    });
    expect(prisma.socialAccount.count).toHaveBeenCalledWith({
      where: { orgId: 'org1', status: 'connected' },
    });
  });

  it('passes through -1 (unlimited) AI allowance untouched', async () => {
    planLimits.limitsFor.mockResolvedValue({ aiCreditsPerMonth: -1 });
    const summary = await service.summary('org1');
    expect(summary.aiCreditsTotal).toBe(-1);
  });

  it('builds a newest-first activity feed from published/scheduled posts, accounts and drafts', async () => {
    const now = Date.now();
    prisma.publishJob.findMany.mockResolvedValue([
      {
        status: 'published',
        updatedAt: new Date(now - 60_000),
        variant: { platform: 'instagram' },
      },
      {
        status: 'scheduled',
        updatedAt: new Date(now - 3_600_000),
        variant: { platform: 'x' },
      },
    ]);
    prisma.socialAccount.findMany.mockResolvedValue([
      { platform: 'linkedin', createdAt: new Date(now - 120_000) },
    ]);
    prisma.contentAsset.findMany.mockResolvedValue([
      { type: 'video', createdAt: new Date(now - 90_000_000) },
    ]);

    const summary = await service.summary('org1');
    const feed = summary.recentActivity;

    // Newest first: IG published (1m) -> LinkedIn connected (2m) -> X scheduled (1h) -> draft (~1d)
    expect(feed.map((e) => e.description)).toEqual([
      'Instagram post published',
      'LinkedIn account connected',
      'X post scheduled',
      'Video draft saved',
    ]);
    expect(feed[0].icon).toBe('published');
    expect(feed[1].icon).toBe('account');
    expect(feed[2].icon).toBe('scheduled');
    expect(feed[3].icon).toBe('draft');
    expect(feed[0].timeAgo).toMatch(/ago|just now/);
  });

  it('caps the activity feed at 6 items', async () => {
    const base = Date.now();
    prisma.publishJob.findMany.mockResolvedValue(
      Array.from({ length: 8 }, (_, i) => ({
        status: 'published',
        updatedAt: new Date(base - i * 1000),
        variant: { platform: 'instagram' },
      })),
    );
    const summary = await service.summary('org1');
    expect(summary.recentActivity).toHaveLength(6);
  });
});
