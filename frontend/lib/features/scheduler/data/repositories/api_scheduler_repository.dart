import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/scheduled_job.dart';

/// Talks to the publish endpoints on behalf of the scheduler (Milestone 7.4):
/// schedule a future post, list the org's jobs, cancel a scheduled one.
class ApiSchedulerRepository {
  ApiSchedulerRepository(this._dio);

  final Dio _dio;

  /// Schedules a variant to publish at [scheduledAt]. Returns the new job id.
  Future<String> schedule({
    required String variantId,
    required String socialAccountId,
    required DateTime scheduledAt,
    String? caption,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/publish/schedule',
      data: {
        'variantId': variantId,
        'socialAccountId': socialAccountId,
        // Sent as UTC ISO-8601; the backend validates it's in the future
        // against its own clock.
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (caption != null) 'caption': caption,
      },
    );
    return response.data!['jobId'] as String;
  }

  /// The org's publish jobs, newest first, optionally filtered by status.
  Future<List<ScheduledJob>> listJobs({ScheduledJobStatus? status}) async {
    final response = await _dio.get<List<dynamic>>(
      '/publish/jobs',
      queryParameters: status == null ? null : {'status': status.name},
    );
    return (response.data ?? [])
        .map((j) => ScheduledJob.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Cancels a still-scheduled job.
  Future<void> cancel(String jobId) async {
    await _dio.delete<void>('/publish/jobs/$jobId');
  }
}

final schedulerRepositoryProvider = Provider<ApiSchedulerRepository>((ref) {
  return ApiSchedulerRepository(ref.watch(apiClientProvider));
});
