/** One published post's time-of-day and how much engagement it earned. */
export interface PostedEngagement {
  postedAt: Date;
  engagement: number;
}

/** A recommended posting slot, ranked by average past engagement. */
export interface BestTimeSlot {
  /** 0 = Sunday … 6 = Saturday (UTC). */
  dayOfWeek: number;
  /** 0–23 (UTC). */
  hour: number;
  averageEngagement: number;
  /** How many past posts fell in this slot — a 1-post slot is weak evidence. */
  sampleCount: number;
}

/**
 * Ranks the org's historical posts into the best (day, hour) slots to post
 * (Milestone 12.2). A plain statistical roll-up, not an LLM call: bucket by
 * UTC weekday+hour, average the engagement in each bucket, and return the
 * top slots.
 *
 * Pure and UTC-based so it's deterministic and unit-testable; the frontend
 * localizes the times for display. Averaged (not summed) so a slot that
 * happens to contain many mediocre posts doesn't outrank a slot with a few
 * strong ones. Ties break toward the better-sampled slot, then earlier in
 * the week/day, for a stable order.
 */
export function rankBestTimes(posts: PostedEngagement[], topN = 5): BestTimeSlot[] {
  const buckets = new Map<string, { total: number; count: number; day: number; hour: number }>();

  for (const post of posts) {
    const day = post.postedAt.getUTCDay();
    const hour = post.postedAt.getUTCHours();
    const key = `${day}-${hour}`;
    const bucket = buckets.get(key) ?? { total: 0, count: 0, day, hour };
    bucket.total += post.engagement;
    bucket.count += 1;
    buckets.set(key, bucket);
  }

  return [...buckets.values()]
    .map((b) => ({
      dayOfWeek: b.day,
      hour: b.hour,
      averageEngagement: b.total / b.count,
      sampleCount: b.count,
    }))
    .sort((a, b) => {
      if (b.averageEngagement !== a.averageEngagement) {
        return b.averageEngagement - a.averageEngagement;
      }
      if (b.sampleCount !== a.sampleCount) return b.sampleCount - a.sampleCount;
      if (a.dayOfWeek !== b.dayOfWeek) return a.dayOfWeek - b.dayOfWeek;
      return a.hour - b.hour;
    })
    .slice(0, topN);
}
