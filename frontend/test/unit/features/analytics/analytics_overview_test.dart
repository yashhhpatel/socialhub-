import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/analytics/domain/entities/analytics_overview.dart';

void main() {
  group('AnalyticsOverview.fromJson', () {
    test('parses totals, per-platform breakdown, top posts and lastUpdated', () {
      final overview = AnalyticsOverview.fromJson({
        'totals': {
          'impressions': 1500,
          'reach': 900,
          'likes': 100,
          'comments': 20,
          'shares': 8,
          'clicks': 2,
        },
        'byPlatform': [
          {
            'platform': 'instagram',
            'postCount': 2,
            'metrics': {'impressions': 1000, 'likes': 60},
          },
        ],
        'postCount': 3,
        'topPosts': [
          {
            'publishJobId': 'job_1',
            'variantId': 'var_1',
            'platform': 'instagram',
            'externalPostId': 'ig_1',
            'metrics': {'impressions': 700, 'likes': 40},
            'engagementScore': 40,
          },
        ],
        'lastUpdated': '2026-08-14T09:00:00.000Z',
      });

      expect(overview.totals.impressions, 1500);
      // engagement = likes + comments + shares + clicks
      expect(overview.totals.engagement, 130);
      expect(overview.byPlatform.single.platform, 'instagram');
      expect(overview.byPlatform.single.metrics.impressions, 1000);
      expect(overview.topPosts.single.engagementScore, 40);
      expect(overview.lastUpdated, DateTime.parse('2026-08-14T09:00:00.000Z'));
      expect(overview.isEmpty, isFalse);
    });

    test('treats a zero-post payload as empty and tolerates missing lists', () {
      final overview = AnalyticsOverview.fromJson({
        'totals': {},
        'postCount': 0,
      });
      expect(overview.isEmpty, isTrue);
      expect(overview.byPlatform, isEmpty);
      expect(overview.topPosts, isEmpty);
      expect(overview.lastUpdated, isNull);
      expect(overview.totals.impressions, 0);
    });
  });
}
