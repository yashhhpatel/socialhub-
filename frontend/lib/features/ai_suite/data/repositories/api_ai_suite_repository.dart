import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/best_time_slot.dart';
import '../../domain/entities/viral_score.dart';

/// The Phase 12 AI-suite endpoints (Milestone 12.3): hashtags, tone rewrite,
/// viral score, and best-time. Caption stays in the publish feature's own
/// repository (Phase 5); these are the four added here.
class ApiAiSuiteRepository {
  ApiAiSuiteRepository(this._dio);

  final Dio _dio;

  Future<List<String>> hashtags(String assetId, {int count = 10}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/hashtags',
      data: {'assetId': assetId, 'count': count},
    );
    return [for (final h in (response.data!['hashtags'] as List<dynamic>)) h as String];
  }

  Future<String> rewriteTone(String text, String tone) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/tone',
      data: {'text': text, 'tone': tone},
    );
    return response.data!['text'] as String;
  }

  Future<ViralScore> viralScore(String assetId, {String? caption}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/viral-score',
      data: {
        'assetId': assetId,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      },
    );
    return ViralScore.fromJson(response.data!);
  }

  Future<List<BestTimeSlot>> bestTimes() async {
    final response = await _dio.get<List<dynamic>>('/ai/best-time');
    return [
      for (final s in (response.data ?? [])) BestTimeSlot.fromJson(s as Map<String, dynamic>),
    ];
  }
}

final aiSuiteRepositoryProvider = Provider<ApiAiSuiteRepository>((ref) {
  return ApiAiSuiteRepository(ref.watch(apiClientProvider));
});

/// Best-time recommendations for the scheduler (Milestone 12.3).
final bestTimesProvider = FutureProvider.autoDispose<List<BestTimeSlot>>((ref) async {
  return ref.watch(aiSuiteRepositoryProvider).bestTimes();
});
