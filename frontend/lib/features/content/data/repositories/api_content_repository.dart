import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../editor/canvas/models/canvas_document.dart';
import '../../domain/entities/content_asset_summary.dart';
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

  @override
  Future<List<ContentAssetSummary>> list() async {
    final response = await _dio.get<Map<String, dynamic>>('/content/assets');
    // Standard pagination envelope: { data: [...], meta: {...} } — see
    // docs/SocialHub_REST_API_Design.md §0.
    final data = response.data!['data'] as List<dynamic>;
    return data
        .map((e) => ContentAssetSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> createAsset({required CanvasDocument document}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/content/assets',
      data: {'type': 'image', 'canvasJson': document.toJson()},
    );
    return response.data!['id'] as String;
  }

  @override
  Future<void> uploadMasterRender({
    required String assetId,
    required Uint8List pngBytes,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        pngBytes,
        filename: 'master.png',
        // The backend's fileFilter allows only jpeg/png/webp/gif and
        // matches on mimetype — omitting contentType makes Dio send
        // application/octet-stream, which that filter rejects.
        contentType: DioMediaType('image', 'png'),
      ),
    });

    final upload = await _dio.post<Map<String, dynamic>>(
      '/content/assets/upload',
      data: form,
    );

    // Two calls, not one: upload is deliberately not tied to any asset
    // (the editor also uses it for per-layer images), so attaching the
    // result is a separate PATCH. publicId is what variant generation
    // addresses transformations by.
    await _dio.patch<Map<String, dynamic>>(
      '/content/assets/$assetId',
      data: {
        'masterImageUrl': upload.data!['url'],
        'masterImagePublicId': upload.data!['publicId'],
      },
    );
  }

  @override
  Future<List<({String platform, String? renderedMediaUrl, String status})>>
      generateVariants({
    required String assetId,
    required List<String> platforms,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/content/assets/$assetId/variants',
      data: {'platforms': platforms},
    );

    final variants = response.data!['variants'] as List<dynamic>;
    return variants.map((v) {
      final m = v as Map<String, dynamic>;
      return (
        platform: m['platform'] as String,
        renderedMediaUrl: m['renderedMediaUrl'] as String?,
        status: m['status'] as String,
      );
    }).toList();
  }
}

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ApiContentRepository(ref.watch(apiClientProvider));
});
