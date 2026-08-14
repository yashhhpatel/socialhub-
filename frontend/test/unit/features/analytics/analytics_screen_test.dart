import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/analytics/domain/entities/analytics_overview.dart';
import 'package:socialhub/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:socialhub/features/analytics/presentation/state/analytics_controller.dart';

AnalyticsOverview _overview() => const AnalyticsOverview(
      totals: Metrics(impressions: 1500, reach: 900, likes: 100, comments: 20, shares: 8),
      byPlatform: [
        PlatformBreakdown(
          platform: 'instagram',
          postCount: 2,
          metrics: Metrics(impressions: 1000, likes: 60, comments: 12, shares: 5),
        ),
        PlatformBreakdown(
          platform: 'x',
          postCount: 1,
          metrics: Metrics(impressions: 500, likes: 40, comments: 8, shares: 3),
        ),
      ],
      postCount: 3,
      topPosts: [
        TopPost(
          publishJobId: 'job_1',
          variantId: 'var_1',
          platform: 'instagram',
          externalPostId: 'ig_1',
          metrics: Metrics(impressions: 700, likes: 40),
          engagementScore: 40,
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget child, {List<Override> overrides = const []}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets('renders totals, the per-platform comparison and top posts with mocked data',
      (tester) async {
    // Tall surface so the whole ListView (which lazily builds) lays out and
    // the bottom "Top posts" section is present to assert on.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      const AnalyticsScreen(),
      overrides: [analyticsOverviewProvider.overrideWith((ref) async => _overview())],
    );
    await tester.pumpAndSettle();

    // Headline + sections rendered.
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Impressions by platform'), findsOneWidget);
    expect(find.text('Platform comparison'), findsOneWidget);
    expect(find.text('Top posts'), findsOneWidget);

    // The comparison is a real table with a row per platform.
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Instagram'), findsWidgets);
    expect(find.text('X'), findsWidgets);

    // Compact stat formatting (1500 -> 1.5K).
    expect(find.text('1.5K'), findsWidgets);
  });

  testWidgets('shows the empty state when there are no posts', (tester) async {
    await _pump(
      tester,
      const AnalyticsScreen(),
      overrides: [
        analyticsOverviewProvider.overrideWith(
          (ref) async => const AnalyticsOverview(
            totals: Metrics(),
            byPlatform: [],
            postCount: 0,
            topPosts: [],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('No analytics yet'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });
}
