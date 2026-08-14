import { rankBestTimes } from './best-time-ranking';

// 2026-08-16 is a Sunday (UTC), so getUTCDay() == 0. Build times off it.
function at(dayOffset: number, hourUtc: number): Date {
  return new Date(Date.UTC(2026, 7, 16 + dayOffset, hourUtc, 0, 0));
}

describe('rankBestTimes', () => {
  it('returns an empty list when there is no history', () => {
    expect(rankBestTimes([])).toEqual([]);
  });

  it('buckets by UTC weekday+hour and ranks by AVERAGE engagement', () => {
    const posts = [
      // Sunday 09:00 — two posts averaging 100.
      { postedAt: at(0, 9), engagement: 150 },
      { postedAt: at(7, 9), engagement: 50 },
      // Monday 18:00 — one strong post.
      { postedAt: at(1, 18), engagement: 120 },
      // Tuesday 03:00 — one weak post.
      { postedAt: at(2, 3), engagement: 5 },
    ];

    const slots = rankBestTimes(posts, 3);

    // Monday 18:00 (avg 120) > Sunday 09:00 (avg 100) > Tuesday 03:00 (avg 5).
    expect(slots[0]).toMatchObject({ dayOfWeek: 1, hour: 18, averageEngagement: 120, sampleCount: 1 });
    expect(slots[1]).toMatchObject({ dayOfWeek: 0, hour: 9, averageEngagement: 100, sampleCount: 2 });
    expect(slots[2]).toMatchObject({ dayOfWeek: 2, hour: 3 });
  });

  it('caps the result to topN', () => {
    const posts = Array.from({ length: 10 }, (_, i) => ({
      postedAt: at(0, i),
      engagement: i,
    }));
    expect(rankBestTimes(posts, 3)).toHaveLength(3);
  });

  it('breaks ties toward the better-sampled, then earlier slot', () => {
    const posts = [
      { postedAt: at(3, 12), engagement: 10 }, // Wed 12:00, 1 sample
      { postedAt: at(1, 8), engagement: 10 }, // Mon 08:00, 2 samples avg 10
      { postedAt: at(8, 8), engagement: 10 },
    ];
    const slots = rankBestTimes(posts, 2);
    // Equal average (10); Monday has more samples, so it ranks first.
    expect(slots[0]).toMatchObject({ dayOfWeek: 1, hour: 8, sampleCount: 2 });
  });
});
