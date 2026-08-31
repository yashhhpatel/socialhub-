import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/publish_models.dart';
import '../../domain/repositories/publish_repository.dart';

class ApiPublishRepository implements PublishRepository {
  ApiPublishRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<PublishableVariant>> variantsForAsset(String assetId) async {
    // GET /content/assets/:id returns the asset with its variants nested
    // (the fix in 78de321 — before that, this endpoint omitted them and
    // the documented polling flow had nothing to poll for).
    final response = await _dio.get<Map<String, dynamic>>('/content/assets/$assetId');
    final variants = response.data!['variants'] as List<dynamic>? ?? [];
    return variants
        .map((v) => PublishableVariant.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<PublishTarget>> targets() async {
    final response = await _dio.get<List<dynamic>>('/social-accounts');
    return (response.data ?? [])
        .map((e) => PublishTarget.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PublishJob> publishNow({
    required String variantId,
    required String socialAccountId,
    String? caption,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/publish/now',
      data: {
        'variantId': variantId,
        'socialAccountId': socialAccountId,
        // Omitted when null, not sent as null: ValidationPipe runs with
        // forbidNonWhitelisted, and the DTO marks caption @IsOptional.
        // An empty string IS sent — it means "post without a caption".
        if (caption != null) 'caption': caption,
      },
    );

    // /publish/now is queue-backed: it returns a `queued` job and a worker
    // runs it a moment later (queued → processing → published | failed). Poll
    // the job until it reaches a terminal state so the caller sees the real
    // outcome (externalPostId on success, lastError on failure) instead of the
    // still-queued row.
    return _pollUntilTerminal(response.data!['jobId'] as String);
  }

  /// Terminal publish states — nothing changes after these.
  static const _terminal = {
    PublishJobStatus.published,
    PublishJobStatus.failed,
    PublishJobStatus.cancelled,
  };

  /// Polls a job (~1s cadence) until it settles or the budget runs out. The
  /// last-read job is returned either way — if it's still processing after the
  /// budget, the caller reports it as in-progress rather than failed.
  Future<PublishJob> _pollUntilTerminal(String jobId) async {
    const maxAttempts = 30; // ~30s ceiling
    var current = await job(jobId);
    var attempts = 0;
    while (!_terminal.contains(current.status) && attempts < maxAttempts) {
      await Future<void>.delayed(const Duration(seconds: 1));
      current = await job(jobId);
      attempts++;
    }
    return current;
  }

  @override
  Future<void> publishCarousel({
    required String socialAccountId,
    required List<String> mediaUrls,
    String? caption,
    DateTime? scheduledAt,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/publish/carousel',
      data: {
        'socialAccountId': socialAccountId,
        'mediaUrls': mediaUrls,
        if (caption != null) 'caption': caption,
        // Sent as UTC ISO-8601; the backend validates it's in the future.
        if (scheduledAt != null)
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<PublishJob> job(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>('/publish/jobs/$jobId');
    return PublishJob.fromJson(response.data!);
  }
}

final publishRepositoryProvider = Provider<PublishRepository>((ref) {
  return ApiPublishRepository(ref.watch(apiClientProvider));
});
