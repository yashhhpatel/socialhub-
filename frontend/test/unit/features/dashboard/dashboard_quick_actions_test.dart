import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:socialhub/features/dashboard/data/api_dashboard_repository.dart';
import 'package:socialhub/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:socialhub/features/scheduler/domain/entities/scheduled_job.dart';
import 'package:socialhub/features/scheduler/presentation/state/scheduler_controller.dart';

DashboardSummary _summary() => const DashboardSummary(
      scheduledPosts: 2,
      publishedPosts: 5,
      drafts: 1,
      connectedAccounts: 1,
      aiCreditsUsed: 10,
      aiCreditsTotal: 500,
      recentActivity: [],
    );

ScheduledJob _job() => ScheduledJob(
      id: 'j1',
      platform: 'instagram',
      status: ScheduledJobStatus.scheduled,
      attemptCount: 0,
      createdAt: DateTime(2026, 1, 1),
      scheduledAt: DateTime(2026, 12, 31, 9, 0),
    );

Widget _marker(String t) => Scaffold(body: Center(child: Text(t)));

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: SingleChildScrollView(child: DashboardScreen()),
          ),
        ),
        GoRoute(path: '/calendar', builder: (_, __) => _marker('CALENDAR')),
        GoRoute(path: '/content', builder: (_, __) => _marker('CONTENT')),
        GoRoute(path: '/analytics', builder: (_, __) => _marker('ANALYTICS')),
        GoRoute(
            path: '/media-library', builder: (_, __) => _marker('MEDIA'),),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  List<ScheduledJob> jobs = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardSummaryProvider.overrideWith((ref) async => _summary()),
        schedulerJobsProvider.overrideWith((ref) async => jobs),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders quick actions and an upcoming post from real jobs',
      (tester) async {
    await _pump(tester, jobs: [_job()]);

    // Quick actions.
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('New post'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);

    // Upcoming posts, sourced from the (overridden) scheduler jobs provider.
    expect(find.text('Upcoming posts'), findsOneWidget);
    expect(find.text('Instagram'), findsWidgets);
    expect(find.text('scheduled'), findsOneWidget);
  });

  testWidgets('shows the empty upcoming state when there are no jobs',
      (tester) async {
    await _pump(tester, jobs: const []);
    expect(find.text('Nothing scheduled yet'), findsOneWidget);
  });

  testWidgets('a quick action navigates to its page', (tester) async {
    await _pump(tester, jobs: const []);
    await tester.ensureVisible(find.text('Schedule'));
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('CALENDAR'), findsOneWidget);
  });
}
