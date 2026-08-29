import { CanonicalMetrics } from './ingestion/metric-normalization';

/** One published post's metrics, flattened for aggregation. */
export interface MetricRow {
  publishJobId: string;
  /** Null for carousel jobs, which publish media directly (no content variant). */
  variantId: string | null;
  platform: string;
  externalPostId: string | null;
  metrics: CanonicalMetrics;
  capturedAt: Date;
}

export interface PlatformBreakdown {
  platform: string;
  postCount: number;
  metrics: CanonicalMetrics;
}

export interface TopPost {
  publishJobId: string;
  variantId: string | null;
  platform: string;
  externalPostId: string | null;
  metrics: CanonicalMetrics;
  /** impressions + engagement, the single number posts are ranked by. */
  engagementScore: number;
}

export interface AnalyticsOverview {
  totals: CanonicalMetrics;
  byPlatform: PlatformBreakdown[];
  postCount: number;
  topPosts: TopPost[];
  /** Most recent capture across all posts, or null if there are none. */
  lastUpdated: Date | null;
}

const METRIC_KEYS: (keyof CanonicalMetrics)[] = [
  'impressions',
  'reach',
  'likes',
  'comments',
  'shares',
  'clicks',
];

function zero(): CanonicalMetrics {
  return { impressions: 0, reach: 0, likes: 0, comments: 0, shares: 0, clicks: 0 };
}

function addInto(acc: CanonicalMetrics, m: CanonicalMetrics): void {
  for (const k of METRIC_KEYS) acc[k] += m[k];
}

/** likes + comments + shares + clicks; the "did people act on it" signal. */
export function engagementOf(m: CanonicalMetrics): number {
  return m.likes + m.comments + m.shares + m.clicks;
}

/**
 * Rolls a flat list of post metrics into the dashboard's overview shape
 * (Milestone 10.3) — org totals, a per-platform breakdown for the
 * cross-platform comparison, the top posts by engagement, and when the data
 * was last refreshed. Pure, so both the GraphQL resolver and the REST
 * fallback build on identical, independently-tested logic.
 */
export function aggregateOverview(rows: MetricRow[], topN = 5): AnalyticsOverview {
  const totals = zero();
  const perPlatform = new Map<string, PlatformBreakdown>();
  let lastUpdated: Date | null = null;

  for (const row of rows) {
    addInto(totals, row.metrics);

    let bucket = perPlatform.get(row.platform);
    if (!bucket) {
      bucket = { platform: row.platform, postCount: 0, metrics: zero() };
      perPlatform.set(row.platform, bucket);
    }
    bucket.postCount++;
    addInto(bucket.metrics, row.metrics);

    if (!lastUpdated || row.capturedAt > lastUpdated) lastUpdated = row.capturedAt;
  }

  const topPosts = [...rows]
    .map((row) => ({
      publishJobId: row.publishJobId,
      variantId: row.variantId,
      platform: row.platform,
      externalPostId: row.externalPostId,
      metrics: row.metrics,
      engagementScore: engagementOf(row.metrics),
    }))
    .sort((a, b) => b.engagementScore - a.engagementScore)
    .slice(0, topN);

  return {
    totals,
    // Stable, human-friendly ordering for the comparison view.
    byPlatform: [...perPlatform.values()].sort((a, b) =>
      a.platform.localeCompare(b.platform),
    ),
    postCount: rows.length,
    topPosts,
    lastUpdated,
  };
}
