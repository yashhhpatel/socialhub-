/// A publish job as the scheduler/calendar view sees it (Milestone 7.4).
///
/// Mirrors the backend PublishJobSummaryDto (GET /publish/jobs). A scheduler-
/// owned projection rather than an import of the publish feature's PublishJob:
/// per docs/architecture §1 a feature never reaches into another feature's
/// internals, and what the calendar needs (platform, when, current status) is
/// a different slice than the publish modal's job model.
class ScheduledJob {
  const ScheduledJob({
    required this.id,
    required this.platform,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    this.scheduledAt,
    this.lastError,
    this.externalPostId,
  });

  final String id;
  final String platform;
  final ScheduledJobStatus status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final String? lastError;
  final String? externalPostId;

  /// Only a still-scheduled post can be cancelled — mirrors the backend's
  /// guard, so the UI doesn't offer a cancel that would just 422.
  bool get isCancellable => status == ScheduledJobStatus.scheduled;

  /// Still moving toward a terminal state — the view polls while any job is.
  bool get isInFlight =>
      status == ScheduledJobStatus.scheduled ||
      status == ScheduledJobStatus.queued ||
      status == ScheduledJobStatus.processing;

  factory ScheduledJob.fromJson(Map<String, dynamic> json) => ScheduledJob(
        id: json['id'] as String,
        platform: json['platform'] as String,
        status: ScheduledJobStatus.fromApiValue(json['status'] as String),
        attemptCount: json['attemptCount'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        scheduledAt: json['scheduledAt'] == null
            ? null
            : DateTime.parse(json['scheduledAt'] as String),
        lastError: json['lastError'] as String?,
        externalPostId: json['externalPostId'] as String?,
      );
}

/// Mirrors the backend PublishJobStatus enum exactly.
enum ScheduledJobStatus {
  queued,
  scheduled,
  processing,
  published,
  failed,
  cancelled;

  static ScheduledJobStatus fromApiValue(String value) => values.firstWhere(
        (s) => s.name == value,
        orElse: () =>
            throw ArgumentError('Unknown publish job status: $value'),
      );
}
