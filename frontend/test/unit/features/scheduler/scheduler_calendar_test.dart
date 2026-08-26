import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/ai_suite/data/repositories/api_ai_suite_repository.dart';
import 'package:socialhub/features/ai_suite/domain/entities/best_time_slot.dart';
import 'package:socialhub/features/scheduler/domain/entities/scheduled_job.dart';
import 'package:socialhub/features/scheduler/presentation/screens/scheduler_screen.dart';
import 'package:socialhub/features/scheduler/presentation/state/scheduler_controller.dart';

/// A fixed day in the current month so the default (month) view always shows
/// the seeded jobs regardless of when the test runs.
DateTime _thisMonth(int day, int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, day, hour);
}

List<ScheduledJob> _jobs() => [
      ScheduledJob(
        id: 'job_ig',
        platform: 'instagram',
        status: ScheduledJobStatus.scheduled,
        attemptCount: 0,
        createdAt: _thisMonth(10, 8),
        scheduledAt: _thisMonth(15, 9),
      ),
      ScheduledJob(
        id: 'job_x',
        platform: 'x',
        status: ScheduledJobStatus.published,
        attemptCount: 1,
        createdAt: _thisMonth(15, 12),
        scheduledAt: null, // an immediate publish sits on its created day
      ),
      ScheduledJob(
        id: 'job_fb',
        platform: 'facebook',
        status: ScheduledJobStatus.scheduled,
        attemptCount: 0,
        createdAt: _thisMonth(18, 8),
        scheduledAt: _thisMonth(20, 8),
      ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required List<ScheduledJob> jobs,
}) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        schedulerJobsProvider.overrideWith((ref) async => jobs),
        bestTimesProvider.overrideWith((ref) async => <BestTimeSlot>[]),
      ],
      child: const MaterialApp(home: Scaffold(body: SchedulerScreen())),
    ),
  );
}

void main() {
  testWidgets('month grid renders with the view toggle and day cells',
      (tester) async {
    await _pump(tester, jobs: _jobs());
    await tester.pumpAndSettle();

    // The calendar chrome: the view toggle and month navigation.
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    // Weekday header + the seeded days are on the grid.
    expect(find.text('Mon'), findsWidgets);
    expect(find.text('15'), findsWidgets);
    expect(find.text('20'), findsWidgets);
  });

  testWidgets('tapping a day with posts opens the reused job cards in a sheet',
      (tester) async {
    await _pump(tester, jobs: _jobs());
    await tester.pumpAndSettle();

    // Day 15 carries two posts (a scheduled IG + an immediate X publish).
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();

    expect(find.text('2 posts'), findsOneWidget);
    // The existing job card (with its status chip) is reused inside the sheet.
    expect(find.text('Instagram'), findsWidgets);
    expect(find.text('X'), findsWidgets);
    expect(find.text('Published'), findsWidgets);
  });

  testWidgets('switching to List shows the original agenda; Week shows a grid',
      (tester) async {
    await _pump(tester, jobs: _jobs());
    await tester.pumpAndSettle();

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    // The agenda's section headers (uppercased) prove the list view rendered.
    expect(find.text('UPCOMING'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    // Week nav still present; no crash laying out the 7-day grid.
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('keeps the empty state when nothing is scheduled', (tester) async {
    await _pump(tester, jobs: const []);
    await tester.pumpAndSettle();

    expect(find.text('Nothing scheduled yet'), findsOneWidget);
    // No calendar chrome when empty.
    expect(find.text('Month'), findsNothing);
  });
}
