import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/brand_kit.dart';

/// Talks to the brand-kit endpoints (Milestone 9.3). The org is implied by
/// the auth token — no org id in the path (see the controller's note on
/// why), so both calls are unparameterised.
class ApiBrandKitRepository {
  ApiBrandKitRepository(this._dio);

  final Dio _dio;

  Future<BrandKit> get() async {
    final response = await _dio.get<Map<String, dynamic>>('/brand-kits');
    return BrandKit.fromJson(response.data!);
  }

  /// Partial update — only the provided fields are sent, so callers can
  /// change (say) just the colours without touching fonts or the logo.
  /// Passing an empty list for [colors]/[fonts] clears them; passing null
  /// leaves them untouched.
  Future<BrandKit> update({
    List<String>? colors,
    List<String>? fonts,
    String? logoUrl,
    String? logoPublicId,
  }) async {
    final body = <String, dynamic>{
      if (colors != null) 'colors': colors,
      if (fonts != null) 'fonts': fonts,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (logoPublicId != null) 'logoPublicId': logoPublicId,
    };
    final response = await _dio.patch<Map<String, dynamic>>('/brand-kits', data: body);
    return BrandKit.fromJson(response.data!);
  }
}

final brandKitRepositoryProvider = Provider<ApiBrandKitRepository>((ref) {
  return ApiBrandKitRepository(ref.watch(apiClientProvider));
});
