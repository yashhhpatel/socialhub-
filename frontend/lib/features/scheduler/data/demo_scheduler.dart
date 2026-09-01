import '../domain/entities/scheduled_job.dart';

/// Sample calendar shown to signed-out visitors: a mix of upcoming scheduled
/// posts and recently published ones across platforms. Built relative to now
/// so the month/week/list views always have something to show. Never shown
/// once a session exists.
List<ScheduledJob> demoScheduledJobs() {
  final now = DateTime.now();
  ScheduledJob job(
    String id,
    String platform,
    ScheduledJobStatus status,
    DateTime when,
  ) =>
      ScheduledJob(
        id: id,
        platform: platform,
        status: status,
        attemptCount: status == ScheduledJobStatus.published ? 1 : 0,
        createdAt: when.subtract(const Duration(days: 1)),
        scheduledAt: when,
        externalPostId:
            status == ScheduledJobStatus.published ? 'demo_$id' : null,
      );

  return [
    job('d1', 'instagram', ScheduledJobStatus.scheduled,
        now.add(const Duration(hours: 5)),),
    job('d2', 'x', ScheduledJobStatus.scheduled,
        now.add(const Duration(days: 1, hours: 2)),),
    job('d3', 'linkedin', ScheduledJobStatus.scheduled,
        now.add(const Duration(days: 2, hours: 1)),),
    job('d4', 'facebook', ScheduledJobStatus.scheduled,
        now.add(const Duration(days: 3)),),
    job('d5', 'instagram', ScheduledJobStatus.published,
        now.subtract(const Duration(days: 1, hours: 3)),),
    job('d6', 'x', ScheduledJobStatus.published,
        now.subtract(const Duration(days: 2)),),
    job('d7', 'threads', ScheduledJobStatus.published,
        now.subtract(const Duration(days: 4, hours: 6)),),
  ];
}
