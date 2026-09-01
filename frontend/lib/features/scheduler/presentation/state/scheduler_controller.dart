import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../data/demo_scheduler.dart';
import '../../data/repositories/api_scheduler_repository.dart';
import '../../domain/entities/scheduled_job.dart';

/// The org's publish jobs for the scheduler view (Milestone 7.4).
///
/// A plain FutureProvider — the view triggers a refresh (ref.invalidate) both
/// on a manual pull and on a timer while anything is still in flight, so the
/// "live status" is polling rather than a socket. Kept simple deliberately:
/// scheduled posts change state on the order of seconds-to-minutes, not
/// milliseconds.
final schedulerJobsProvider = FutureProvider.autoDispose<List<ScheduledJob>>(
  (ref) async {
    if (ref.watch(demoModeProvider)) return demoScheduledJobs();
    return ref.watch(schedulerRepositoryProvider).listJobs();
  },
);

/// Cancels a scheduled job, then refreshes the list so the row reflects it.
final cancelJobProvider = Provider.autoDispose(
  (ref) => (String jobId) async {
    await ref.read(schedulerRepositoryProvider).cancel(jobId);
    ref.invalidate(schedulerJobsProvider);
  },
);
