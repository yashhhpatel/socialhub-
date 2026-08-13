import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/scheduler/domain/entities/scheduled_job.dart';

Map<String, dynamic> _json({
  String status = 'scheduled',
  String? scheduledAt = '2026-09-01T09:00:00.000Z',
  String platform = 'x',
  int attemptCount = 0,
  String? lastError,
}) =>
    {
      'id': 'job_1',
      'platform': platform,
      'status': status,
      'attemptCount': attemptCount,
      'createdAt': '2026-08-14T10:00:00.000Z',
      'scheduledAt': scheduledAt,
      'lastError': lastError,
      'externalPostId': null,
    };

void main() {
  group('ScheduledJob.fromJson', () {
    test('parses a scheduled job with its time', () {
      final job = ScheduledJob.fromJson(_json());
      expect(job.status, ScheduledJobStatus.scheduled);
      expect(job.scheduledAt, DateTime.parse('2026-09-01T09:00:00.000Z'));
      expect(job.platform, 'x');
    });

    test('handles a null scheduledAt (an immediate publish has none)', () {
      final job = ScheduledJob.fromJson(_json(status: 'published', scheduledAt: null));
      expect(job.scheduledAt, isNull);
      expect(job.status, ScheduledJobStatus.published);
    });

    test('throws on an unknown status rather than guessing', () {
      expect(
        () => ScheduledJob.fromJson(_json(status: 'exploded')),
        throwsArgumentError,
      );
    });

    test('parses every status the backend enum can emit', () {
      for (final s in ['queued', 'scheduled', 'processing', 'published', 'failed', 'cancelled']) {
        expect(ScheduledJob.fromJson(_json(status: s)).status.name, s);
      }
    });
  });

  group('ScheduledJob state helpers', () {
    test('only a scheduled job is cancellable', () {
      expect(ScheduledJob.fromJson(_json(status: 'scheduled')).isCancellable, isTrue);
      for (final s in ['queued', 'processing', 'published', 'failed', 'cancelled']) {
        expect(
          ScheduledJob.fromJson(_json(status: s)).isCancellable,
          isFalse,
          reason: '$s must not be cancellable',
        );
      }
    });

    test('in-flight covers pre-terminal states only', () {
      for (final s in ['scheduled', 'queued', 'processing']) {
        expect(ScheduledJob.fromJson(_json(status: s)).isInFlight, isTrue, reason: s);
      }
      for (final s in ['published', 'failed', 'cancelled']) {
        expect(ScheduledJob.fromJson(_json(status: s)).isInFlight, isFalse, reason: s);
      }
    });
  });
}
