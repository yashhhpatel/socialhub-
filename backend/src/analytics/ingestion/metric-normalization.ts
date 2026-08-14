import { Platform } from '@prisma/client';

/**
 * The canonical, cross-platform shape every post's metrics are mapped into
 * (Phase 10). Each platform's insights API speaks a different dialect
 * (impression_count vs impressions, retweets vs shares); the normalizers
 * below are the single translation layer, so everything downstream — the
 * PostMetric table, the dashboard queries, the charts — deals with one
 * schema. A platform that genuinely doesn't report a metric contributes 0
 * for it rather than null, so aggregates never have to special-case gaps.
 */
export interface CanonicalMetrics {
  impressions: number;
  reach: number;
  likes: number;
  comments: number;
  shares: number;
  clicks: number;
}

const ZERO: CanonicalMetrics = {
  impressions: 0,
  reach: 0,
  likes: 0,
  comments: 0,
  shares: 0,
  clicks: 0,
};

/** Coerces an unknown JSON value to a non-negative integer, defaulting to 0. */
function num(value: unknown): number {
  const n = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(n) && n > 0 ? Math.round(n) : 0;
}

/**
 * The Meta insights shape (`{ data: [{ name, values: [{ value }] }] }`),
 * used by Instagram, Facebook, and Threads. Threads reports lifetime metrics
 * under `total_value.value` instead of `values[0].value`, so both are read.
 * Returns a name→value map; order is never assumed.
 */
function metaInsightsByName(data: unknown): Map<string, unknown> {
  const byName = new Map<string, unknown>();
  if (!Array.isArray(data)) return byName;
  for (const entry of data as Array<{
    name?: string;
    values?: Array<{ value?: unknown }>;
    total_value?: { value?: unknown };
  }>) {
    if (entry?.name) {
      byName.set(entry.name, entry.total_value?.value ?? entry.values?.[0]?.value);
    }
  }
  return byName;
}

/**
 * Instagram Graph media insights: `{ data: [{ name, values: [{ value }] }] }`.
 * Mapped by metric name — order isn't guaranteed, and which metrics come
 * back varies by media type, so a missing one simply stays 0.
 */
export function normalizeInstagram(raw: unknown): CanonicalMetrics {
  const byName = metaInsightsByName((raw as { data?: unknown })?.data);
  return {
    impressions: num(byName.get('impressions')),
    reach: num(byName.get('reach')),
    likes: num(byName.get('likes')),
    comments: num(byName.get('comments')),
    shares: num(byName.get('shares')),
    clicks: 0, // Instagram doesn't expose post-level link clicks here.
  };
}

/**
 * Facebook Page post: insights (impressions/reach) come from the
 * `insights.data` array, while engagement counts come from the object's
 * own summary edges — so ingestion requests them together and this maps the
 * combined payload:
 * `{ insights: { data: [...] }, likes: { summary: { total_count } },
 *    comments: { summary: { total_count } }, shares: { count } }`.
 */
export function normalizeFacebook(raw: unknown): CanonicalMetrics {
  const r = raw as {
    insights?: { data?: unknown };
    likes?: { summary?: { total_count?: unknown } };
    comments?: { summary?: { total_count?: unknown } };
    shares?: { count?: unknown };
  } | null;
  const insights = metaInsightsByName(r?.insights?.data);

  return {
    impressions: num(insights.get('post_impressions')),
    reach: num(insights.get('post_impressions_unique')),
    likes: num(r?.likes?.summary?.total_count),
    comments: num(r?.comments?.summary?.total_count),
    shares: num(r?.shares?.count),
    clicks: num(insights.get('post_clicks')),
  };
}

/**
 * Threads media insights: `views`, `likes`, `replies`, `reposts`, `quotes`
 * (lifetime values under `total_value`). Shares combines reposts + quotes,
 * the two re-share paths; Threads reports no distinct "reach".
 */
export function normalizeThreads(raw: unknown): CanonicalMetrics {
  const byName = metaInsightsByName((raw as { data?: unknown })?.data);
  return {
    impressions: num(byName.get('views')),
    reach: 0,
    likes: num(byName.get('likes')),
    comments: num(byName.get('replies')),
    shares: num(byName.get('reposts')) + num(byName.get('quotes')),
    clicks: 0,
  };
}

/**
 * LinkedIn socialActions on a share:
 * `{ likesSummary: { totalLikes }, commentsSummary: { aggregatedTotalComments } }`.
 * Member-post impressions/reach aren't available without organization-level
 * analytics (an approved-app, org-context API), so they stay 0 here —
 * honestly absent rather than faked. Extending to org analytics is future
 * work.
 */
export function normalizeLinkedIn(raw: unknown): CanonicalMetrics {
  const r = raw as {
    likesSummary?: { totalLikes?: unknown };
    commentsSummary?: { aggregatedTotalComments?: unknown; count?: unknown };
  } | null;
  return {
    impressions: 0,
    reach: 0,
    likes: num(r?.likesSummary?.totalLikes),
    comments: num(
      r?.commentsSummary?.aggregatedTotalComments ?? r?.commentsSummary?.count,
    ),
    shares: 0,
    clicks: 0,
  };
}

/**
 * X tweet lookup with `tweet.fields=public_metrics`:
 * `{ data: { public_metrics: { impression_count, like_count, reply_count,
 * retweet_count, quote_count } } }`. X has no "reach"; shares combines
 * retweets and quotes, the two ways a tweet is re-shared.
 */
export function normalizeX(raw: unknown): CanonicalMetrics {
  const m = (raw as { data?: { public_metrics?: Record<string, unknown> } })?.data
    ?.public_metrics;
  if (!m) return { ...ZERO };

  return {
    impressions: num(m.impression_count),
    reach: 0,
    likes: num(m.like_count),
    comments: num(m.reply_count),
    shares: num(m.retweet_count) + num(m.quote_count),
    clicks: 0,
  };
}

/**
 * Dispatches to the right normalizer. Throws for a platform whose ingestion
 * isn't wired yet (Milestone 10.2 adds Facebook/Threads/LinkedIn) rather
 * than silently returning zeros, which would look like a real "no
 * engagement" result.
 */
export function normalizeMetrics(platform: Platform, raw: unknown): CanonicalMetrics {
  switch (platform) {
    case Platform.instagram:
      return normalizeInstagram(raw);
    case Platform.x:
      return normalizeX(raw);
    case Platform.facebook:
      return normalizeFacebook(raw);
    case Platform.threads:
      return normalizeThreads(raw);
    case Platform.linkedin:
      return normalizeLinkedIn(raw);
  }
}
