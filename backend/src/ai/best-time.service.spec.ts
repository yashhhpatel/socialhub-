import { BestTimeService } from './best-time.service';

describe('BestTimeService', () => {
  let service: BestTimeService;
  let prisma: { postMetric: { findMany: jest.Mock } };

  beforeEach(() => {
    prisma = { postMetric: { findMany: jest.fn() } };
    service = new BestTimeService(prisma as never);
  });

  it('scopes to the org through publishJob.socialAccount.orgId', async () => {
    prisma.postMetric.findMany.mockResolvedValue([]);
    await service.recommend('org_1');
    const where = prisma.postMetric.findMany.mock.calls[0][0].where;
    expect(where).toEqual({ publishJob: { socialAccount: { orgId: 'org_1' } } });
  });

  it('derives post time from the publish job and engagement from the metric', async () => {
    prisma.postMetric.findMany.mockResolvedValue([
      {
        likes: 10,
        comments: 2,
        shares: 1,
        clicks: 0,
        publishJob: { createdAt: new Date(Date.UTC(2026, 7, 17, 9, 0, 0)) }, // Mon 09:00
      },
    ]);

    const slots = await service.recommend('org_1');

    expect(slots).toHaveLength(1);
    expect(slots[0]).toMatchObject({
      dayOfWeek: 1, // Monday
      hour: 9,
      averageEngagement: 13, // 10 + 2 + 1 + 0
      sampleCount: 1,
    });
  });

  it('returns an empty list when the org has no metrics yet', async () => {
    prisma.postMetric.findMany.mockResolvedValue([]);
    expect(await service.recommend('org_1')).toEqual([]);
  });
});
