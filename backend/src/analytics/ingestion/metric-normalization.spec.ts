import { Platform } from '@prisma/client';

import {
  normalizeFacebook,
  normalizeInstagram,
  normalizeLinkedIn,
  normalizeMetrics,
  normalizeThreads,
  normalizeX,
} from './metric-normalization';

describe('metric normalization', () => {
  describe('normalizeInstagram', () => {
    it('maps insight names to canonical fields regardless of order', () => {
      const raw = {
        data: [
          { name: 'reach', values: [{ value: 500 }] },
          { name: 'impressions', values: [{ value: 900 }] },
          { name: 'likes', values: [{ value: 42 }] },
          { name: 'comments', values: [{ value: 7 }] },
          { name: 'shares', values: [{ value: 3 }] },
        ],
      };

      expect(normalizeInstagram(raw)).toEqual({
        impressions: 900,
        reach: 500,
        likes: 42,
        comments: 7,
        shares: 3,
        clicks: 0,
      });
    });

    it('defaults a metric the payload omits to 0, not null', () => {
      const raw = { data: [{ name: 'impressions', values: [{ value: 10 }] }] };
      const result = normalizeInstagram(raw);
      expect(result.impressions).toBe(10);
      expect(result.reach).toBe(0);
      expect(result.likes).toBe(0);
    });

    it('is defensive against a malformed payload', () => {
      expect(normalizeInstagram(null)).toEqual({
        impressions: 0,
        reach: 0,
        likes: 0,
        comments: 0,
        shares: 0,
        clicks: 0,
      });
      expect(normalizeInstagram({ data: 'nope' })).toMatchObject({ impressions: 0 });
    });
  });

  describe('normalizeX', () => {
    it('maps public_metrics, combining retweets + quotes into shares', () => {
      const raw = {
        data: {
          public_metrics: {
            impression_count: 1200,
            like_count: 80,
            reply_count: 12,
            retweet_count: 5,
            quote_count: 4,
          },
        },
      };

      expect(normalizeX(raw)).toEqual({
        impressions: 1200,
        reach: 0, // X has no reach metric
        likes: 80,
        comments: 12,
        shares: 9, // 5 retweets + 4 quotes
        clicks: 0,
      });
    });

    it('is defensive against a missing public_metrics block', () => {
      expect(normalizeX({ data: {} }).impressions).toBe(0);
      expect(normalizeX(null).shares).toBe(0);
    });

    it('coerces string counts and ignores negatives', () => {
      const raw = {
        data: { public_metrics: { impression_count: '300', like_count: -5 } },
      };
      const result = normalizeX(raw);
      expect(result.impressions).toBe(300);
      expect(result.likes).toBe(0);
    });
  });

  describe('normalizeFacebook', () => {
    it('combines insights with the object engagement summaries', () => {
      const raw = {
        insights: {
          data: [
            { name: 'post_impressions', values: [{ value: 2000 }] },
            { name: 'post_impressions_unique', values: [{ value: 1500 }] },
            { name: 'post_clicks', values: [{ value: 33 }] },
          ],
        },
        likes: { summary: { total_count: 120 } },
        comments: { summary: { total_count: 18 } },
        shares: { count: 6 },
      };

      expect(normalizeFacebook(raw)).toEqual({
        impressions: 2000,
        reach: 1500,
        likes: 120,
        comments: 18,
        shares: 6,
        clicks: 33,
      });
    });

    it('is defensive when engagement edges are absent', () => {
      expect(normalizeFacebook({ insights: { data: [] } })).toMatchObject({
        likes: 0,
        shares: 0,
      });
    });
  });

  describe('normalizeThreads', () => {
    it('reads lifetime total_value metrics and folds reposts + quotes into shares', () => {
      const raw = {
        data: [
          { name: 'views', total_value: { value: 800 } },
          { name: 'likes', total_value: { value: 40 } },
          { name: 'replies', total_value: { value: 6 } },
          { name: 'reposts', total_value: { value: 3 } },
          { name: 'quotes', total_value: { value: 2 } },
        ],
      };

      expect(normalizeThreads(raw)).toEqual({
        impressions: 800,
        reach: 0,
        likes: 40,
        comments: 6,
        shares: 5,
        clicks: 0,
      });
    });
  });

  describe('normalizeLinkedIn', () => {
    it('maps socialActions summaries; impressions stay 0 (not available)', () => {
      const raw = {
        likesSummary: { totalLikes: 55 },
        commentsSummary: { aggregatedTotalComments: 9 },
      };

      expect(normalizeLinkedIn(raw)).toEqual({
        impressions: 0,
        reach: 0,
        likes: 55,
        comments: 9,
        shares: 0,
        clicks: 0,
      });
    });

    it('falls back to commentsSummary.count when aggregated is absent', () => {
      expect(normalizeLinkedIn({ commentsSummary: { count: 4 } }).comments).toBe(4);
    });
  });

  describe('normalizeMetrics dispatch', () => {
    it('routes to each platform normalizer', () => {
      expect(
        normalizeMetrics(Platform.instagram, {
          data: [{ name: 'likes', values: [{ value: 1 }] }],
        }).likes,
      ).toBe(1);
      expect(
        normalizeMetrics(Platform.facebook, { likes: { summary: { total_count: 2 } } }).likes,
      ).toBe(2);
      expect(
        normalizeMetrics(Platform.threads, {
          data: [{ name: 'likes', total_value: { value: 3 } }],
        }).likes,
      ).toBe(3);
      expect(
        normalizeMetrics(Platform.linkedin, { likesSummary: { totalLikes: 4 } }).likes,
      ).toBe(4);
    });
  });
});
