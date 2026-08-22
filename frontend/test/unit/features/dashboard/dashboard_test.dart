import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/dashboard/data/api_dashboard_repository.dart';
import 'package:socialhub/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:socialhub/features/dashboard/presentation/screens/dashboard_screen.dart';

DashboardSummary _summary({
  int aiTotal = 500,
  List<ActivityItem> activity = const [],
}) {
  return DashboardSummary(
    scheduledPosts: 3,
    publishedPosts: 17,
    drafts: 4,
    connectedAccounts: 2,
    aiCreditsUsed: 42,
    aiCreditsTotal: aiTotal,
    recentActivity: activity,
  );
}

Widget _host(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: DashboardScreen())),
    ),
  );
}

void main() {
  group('DashboardSummary.fromJson', () {
    test('parses fields and activity', () {
      final s = DashboardSummary.fromJson({
        'scheduledPosts': 3,
        'publishedPosts': 17,
        'drafts': 4,
        'connectedAccounts': 2,
        'aiCreditsUsed': 42,
        'aiCreditsTotal': 500,
        'recentActivity': [
          {'description': 'Instagram post published', 'timeAgo': '2h ago', 'icon': 'published'},
        ],
      });
      expect(s.publishedPosts, 17);
      expect(s.aiCreditsUnlimited, isFalse);
      expect(s.recentActivity.single.description, 'Instagram post published');
    });

    test('treats -1 total as unlimited', () {
      final s = DashboardSummary.fromJson({'aiCreditsTotal': -1});
      expect(s.aiCreditsUnlimited, isTrue);
      expect(s.scheduledPosts, 0); // missing fields default to 0
    });
  });

  testWidgets('shows real data on success', (tester) async {
    await tester.pumpWidget(_host(<Override>[
      dashboardSummaryProvider.overrideWith((ref) async => _summary()),
    ],),);
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('17'), findsOneWidget); // published posts
    expect(find.text('42 / 500'), findsOneWidget); // AI credits
  });

  testWidgets('renders unlimited AI credits without a denominator',
      (tester) async {
    await tester.pumpWidget(_host(<Override>[
      dashboardSummaryProvider.overrideWith((ref) async => _summary(aiTotal: -1)),
    ],),);
    await tester.pumpAndSettle();

    expect(find.text('Unlimited'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('shows an error with a working retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_host(<Override>[
      dashboardSummaryProvider.overrideWith((ref) async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return _summary();
      }),
    ],),);
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't load your dashboard"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Second attempt succeeds → real content renders.
    expect(find.text('Overview'), findsOneWidget);
    expect(calls, greaterThanOrEqualTo(2));
  });

  testWidgets('shows the empty activity state when there is none',
      (tester) async {
    await tester.pumpWidget(_host(<Override>[
      dashboardSummaryProvider.overrideWith((ref) async => _summary()),
    ],),);
    await tester.pumpAndSettle();

    expect(find.text('No recent activity yet.'), findsOneWidget);
  });
}
