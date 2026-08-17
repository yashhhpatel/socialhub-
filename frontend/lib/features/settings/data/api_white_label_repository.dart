import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_token_store.dart';
import '../domain/white_label.dart';

/// Reads/writes an org's white-label branding (Milestone 15.4).
class ApiWhiteLabelRepository {
  ApiWhiteLabelRepository(this._dio);

  final Dio _dio;

  Future<WhiteLabel> get() async {
    final response = await _dio.get<Map<String, dynamic>>('/organizations/white-label');
    return WhiteLabel.fromJson(response.data!);
  }

  /// Updates branding for [orgId]. A field passed as null clears it (reverts
  /// to default); omitted fields are left unchanged.
  Future<WhiteLabel> update(
    String orgId, {
    Object? logoUrl = _unset,
    Object? primaryColor = _unset,
  }) async {
    final body = <String, dynamic>{
      if (!identical(logoUrl, _unset)) 'logoUrl': logoUrl,
      if (!identical(primaryColor, _unset)) 'primaryColor': primaryColor,
    };
    final response = await _dio.patch<Map<String, dynamic>>(
      '/organizations/$orgId/white-label',
      data: body,
    );
    return WhiteLabel.fromJson(response.data!);
  }

  static const _unset = Object();
}

final whiteLabelRepositoryProvider = Provider<ApiWhiteLabelRepository>((ref) {
  return ApiWhiteLabelRepository(ref.watch(apiClientProvider));
});

/// The current org's branding, applied app-wide (Milestone 15.4).
///
/// Returns null when there's no session (the login screen must render in the
/// default theme) or on any error, so branding is strictly additive and never
/// blocks the app from theming itself.
final whiteLabelProvider = FutureProvider<WhiteLabel?>((ref) async {
  final tokens = ref.watch(authTokenStoreProvider);
  if (tokens == null) return null;
  try {
    return await ref.watch(whiteLabelRepositoryProvider).get();
  } catch (_) {
    return null;
  }
});
