import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../editor/canvas/models/canvas_document.dart';
import '../../domain/entities/template.dart';

/// Talks to the template endpoints (Milestone 9.4). Org is implied by the
/// auth token, so nothing is parameterised by org.
class ApiTemplatesRepository {
  ApiTemplatesRepository(this._dio);

  final Dio _dio;

  Future<List<TemplateSummary>> list() async {
    final response = await _dio.get<List<dynamic>>('/templates');
    return (response.data ?? [])
        .map((t) => TemplateSummary.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<TemplateDetail> get(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/templates/$id');
    return TemplateDetail.fromJson(response.data!);
  }

  /// Saves the given canvas as a reusable template.
  Future<TemplateSummary> create({
    required String name,
    required CanvasDocument document,
    String? category,
    String? thumbnailUrl,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/templates',
      data: {
        'name': name,
        'canvasJson': document.toJson(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      },
    );
    return TemplateSummary.fromJson(response.data!);
  }
}

final templatesRepositoryProvider = Provider<ApiTemplatesRepository>((ref) {
  return ApiTemplatesRepository(ref.watch(apiClientProvider));
});
