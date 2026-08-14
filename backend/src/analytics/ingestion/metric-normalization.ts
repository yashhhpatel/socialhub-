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
 * Instagram Graph media insights: `{ data: [{ name, values: [{ value }] }] }`.
 * Mapped by metric name — order isn't guaranteed, and which metrics come
 * back varies by media type, so a missing one simply stays 0.
 */
export function normalizeInstagram(raw: unknown): CanonicalMetrics {
  const data = (raw as { data?: Array<{ name?: string; values?: Array<{ value?: unknown }> }> })
    ?.data;
  if (!Array.isArray(data)) return { ...ZERO };

  const byName = new Map<string, unknown>();
  for (const entry of data) {
    if (entry?.name) byName.set(entry.name, entry.values?.[0]?.value);
  }

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
    default:
      throw new Error(`Metric normalization for ${platform} is not implemented yet.`);
  }
}
