import { MetricRow, aggregateOverview, engagementOf } from './analytics-aggregation';
import { CanonicalMetrics } from './ingestion/metric-normalization';

function row(overrides: {
  platform: string;
  publishJobId?: string;
  variantId?: string;
  externalPostId?: string | null;
  capturedAt?: Date;
  metrics?: Partial<CanonicalMetrics>;
}): MetricRow {
  return {
    publishJobId: overrides.publishJobId ?? `job_${Math.random()}`,
    variantId: overrides.variantId ?? 'var_1',
    platform: overrides.platform,
    externalPostId: overrides.externalPostId ?? 'ext_1',
    capturedAt: overrides.capturedAt ?? new Date('2026-08-14T00:00:00Z'),
    metrics: {
      impressions: 0,
      reach: 0,
      likes: 0,
      comments: 0,
      shares: 0,
      clicks: 0,
      ...overrides.metrics,
    },
  };
}

describe('aggregateOverview', () => {
  it('returns an all-zero, empty overview for no rows', () => {
    const result = aggregateOverview([]);
    expect(result.postCount).toBe(0);
    expect(result.totals.impressions).toBe(0);
    expect(result.byPlatform).toEqual([]);
    expect(result.topPosts).toEqual([]);
    expect(result.lastUpdated).toBeNull();
  });

  it('sums totals across every post', () => {
    const result = aggregateOverview([
      row({ platform: 'instagram', metrics: { impressions: 100, likes: 10 } }),
      row({ platform: 'x', metrics: { impressions: 50, likes: 5 } }),
    ]);
    expect(result.totals.impressions).toBe(150);
    expect(result.totals.likes).toBe(15);
    expect(result.postCount).toBe(2);
  });

  it('breaks down by platform, counting posts and summing per platform', () => {
    const result = aggregateOverview([
      row({ platform: 'instagram', metrics: { impressions: 100 } }),
      row({ platform: 'instagram', metrics: { impressions: 40 } }),
      row({ platform: 'x', metrics: { impressions: 50 } }),
    ]);

    const ig = result.byPlatform.find((p) => p.platform === 'instagram')!;
    const x = result.byPlatform.find((p) => p.platform === 'x')!;
    expect(ig.postCount).toBe(2);
    expect(ig.metrics.impressions).toBe(140);
    expect(x.postCount).toBe(1);
    // Alphabetical platform order for a stable comparison view.
    expect(result.byPlatform.map((p) => p.platform)).toEqual(['instagram', 'x']);
  });

  it('ranks top posts by engagement, highest first, capped to topN', () => {
    const result = aggregateOverview(
      [
        row({ publishJobId: 'low', platform: 'x', metrics: { likes: 1 } }),
        row({ publishJobId: 'high', platform: 'instagram', metrics: { likes: 50, shares: 10 } }),
        row({ publishJobId: 'mid', platform: 'x', metrics: { likes: 20 } }),
      ],
      2,
    );

    expect(result.topPosts).toHaveLength(2);
    expect(result.topPosts[0].publishJobId).toBe('high');
    expect(result.topPosts[0].engagementScore).toBe(60);
    expect(result.topPosts[1].publishJobId).toBe('mid');
  });

  it('reports the most recent capture as lastUpdated', () => {
    const result = aggregateOverview([
      row({ platform: 'x', capturedAt: new Date('2026-08-10T00:00:00Z') }),
      row({ platform: 'instagram', capturedAt: new Date('2026-08-14T09:00:00Z') }),
    ]);
    expect(result.lastUpdated).toEqual(new Date('2026-08-14T09:00:00Z'));
  });

  it('engagementOf excludes impressions/reach (passive), counts actions', () => {
    expect(
      engagementOf({
        impressions: 1000,
        reach: 800,
        likes: 5,
        comments: 3,
        shares: 2,
        clicks: 1,
      }),
    ).toBe(11);
  });
});
