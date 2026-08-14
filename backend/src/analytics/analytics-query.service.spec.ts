import { AnalyticsQueryService } from './analytics-query.service';

describe('AnalyticsQueryService', () => {
  let service: AnalyticsQueryService;
  let prisma: { postMetric: { findMany: jest.Mock } };

  const metricRow = {
    publishJobId: 'job_1',
    impressions: 100,
    reach: 80,
    likes: 10,
    comments: 2,
    shares: 1,
    clicks: 0,
    capturedAt: new Date('2026-08-14T00:00:00Z'),
    publishJob: {
      variantId: 'var_1',
      externalPostId: 'ext_1',
      socialAccount: { platform: 'instagram' },
    },
  };

  beforeEach(() => {
    prisma = { postMetric: { findMany: jest.fn().mockResolvedValue([metricRow]) } };
    service = new AnalyticsQueryService(prisma as never);
  });

  describe('overview', () => {
    it('scopes to the org through publishJob.socialAccount.orgId', async () => {
      await service.overview('org_1');
      const where = prisma.postMetric.findMany.mock.calls[0][0].where;
      expect(where).toEqual({ publishJob: { socialAccount: { orgId: 'org_1' } } });
    });

    it('maps rows into canonical metrics and aggregates them', async () => {
      const overview = await service.overview('org_1');
      expect(overview.postCount).toBe(1);
      expect(overview.totals.impressions).toBe(100);
      expect(overview.byPlatform[0].platform).toBe('instagram');
      expect(overview.topPosts[0].variantId).toBe('var_1');
    });
  });

  describe('postMetrics', () => {
    it('scopes by both variant and org', async () => {
      await service.postMetrics('org_1', 'var_1');
      const where = prisma.postMetric.findMany.mock.calls[0][0].where;
      expect(where).toEqual({
        publishJob: { variantId: 'var_1', socialAccount: { orgId: 'org_1' } },
      });
    });

    it('returns flattened metric rows', async () => {
      const rows = await service.postMetrics('org_1', 'var_1');
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({
        publishJobId: 'job_1',
        platform: 'instagram',
        variantId: 'var_1',
      });
      expect(rows[0].metrics.impressions).toBe(100);
    });
  });
});
