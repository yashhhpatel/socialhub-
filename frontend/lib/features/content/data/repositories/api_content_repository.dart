import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../editor/canvas/models/canvas_document.dart';
import '../../domain/repositories/content_repository.dart';

class ApiContentRepository implements ContentRepository {
  ApiContentRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> saveCanvas({
    required String assetId,
    required CanvasDocument document,
  }) async {
    await _dio.patch<Map<String, dynamic>>(
      '/content/assets/$assetId',
      data: {'canvasJson': document.toJson()},
    );
  }

  @override
  Future<CanvasDocument> loadCanvas(String assetId) async {
    final response = await _dio.get<Map<String, dynamic>>('/content/assets/$assetId');
    final canvasJson = response.data!['canvasJson'] as Map<String, dynamic>;
    return CanvasDocument.fromJson(canvasJson);
  }
}

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ApiContentRepository(ref.watch(apiClientProvider));
});
