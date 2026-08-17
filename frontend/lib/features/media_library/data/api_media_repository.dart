import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// A hosted upload result — the CDN URL to reuse in designs, brand kit, or
/// white-label branding.
class UploadedMedia {
  const UploadedMedia({required this.url, required this.publicId, required this.name});

  final String url;
  final String publicId;
  final String name;

  bool get isVideo =>
      url.contains('/video/') || RegExp(r'\.(mp4|mov|webm)(\?|$)').hasMatch(url);
}

/// Uploads media through the existing content upload endpoint (Cloudinary),
/// which returns a public URL + id. There's no server-side media catalogue
/// yet, so this returns the single upload; the screen keeps a session list.
class ApiMediaRepository {
  ApiMediaRepository(this._dio);

  final Dio _dio;

  Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String name,
    required String mimeType,
  }) async {
    final parts = mimeType.split('/');
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: name,
        contentType: parts.length == 2 ? DioMediaType(parts[0], parts[1]) : null,
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/content/assets/upload',
      data: form,
    );
    return UploadedMedia(
      url: response.data!['url'] as String,
      publicId: response.data!['publicId'] as String,
      name: name,
    );
  }
}

final mediaRepositoryProvider = Provider<ApiMediaRepository>((ref) {
  return ApiMediaRepository(ref.watch(apiClientProvider));
});
