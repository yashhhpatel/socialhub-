import { Platform } from '@prisma/client';

import {
  normalizeInstagram,
  normalizeMetrics,
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

  describe('normalizeMetrics dispatch', () => {
    it('routes to the platform normalizer', () => {
      const ig = normalizeMetrics(Platform.instagram, {
        data: [{ name: 'likes', values: [{ value: 1 }] }],
      });
      expect(ig.likes).toBe(1);
    });

    it('throws for a platform whose ingestion is not wired yet', () => {
      expect(() => normalizeMetrics(Platform.linkedin, {})).toThrow(/not implemented/i);
    });
  });
});
