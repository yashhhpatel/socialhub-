import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../domain/media_item.dart';
import 'demo_media.dart';

/// Talks to the backend /media endpoints (Phase 19). Uploads persist to the
/// org's media library (a `MediaAsset` row), so they survive across sessions —
/// no more session-only list.
class ApiMediaRepository {
  ApiMediaRepository(this._dio);

  final Dio _dio;

  Future<List<MediaItem>> list() async {
    final response = await _dio.get<List<dynamic>>('/media');
    return (response.data ?? [])
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MediaItem> upload({
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
      '/media/upload',
      data: form,
    );
    return MediaItem.fromJson(response.data!);
  }

  Future<void> delete(String id) => _dio.delete<void>('/media/$id');
}

final mediaRepositoryProvider = Provider<ApiMediaRepository>((ref) {
  return ApiMediaRepository(ref.watch(apiClientProvider));
});

/// The org's persisted media library. Re-evaluates on login/logout and returns
/// an empty list when logged out (the screen shows its logged-out empty state
/// rather than surfacing a 401).
final mediaLibraryProvider =
    FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  // Signed out: an explorable sample library; signed in: the real one.
  if (ref.watch(demoModeProvider)) return demoMediaItems;
  return ref.watch(mediaRepositoryProvider).list();
});
