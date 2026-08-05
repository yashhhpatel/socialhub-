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
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/publish/now',
      data: {'variantId': variantId, 'socialAccountId': socialAccountId},
    );

    // POST /publish/now returns only { jobId, status } — read the full
    // job back so the caller gets externalPostId and lastError too.
    return job(response.data!['jobId'] as String);
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
