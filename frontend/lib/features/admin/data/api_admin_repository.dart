import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_token_store.dart';

/// Talks to the platform-admin API (`/admin/*`, Phase 21). Every call is gated
/// server-side by PlatformAdminGuard; the client also hides the panel from
/// non-admins, but the server is the real boundary.
class ApiAdminRepository {
  ApiAdminRepository(this._dio);

  final Dio _dio;

  /// Confirms the caller is a platform admin; returns the admin's email.
  /// Throws (401/403) otherwise.
  Future<String> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/me');
    return response.data!['email'] as String;
  }
}

final adminRepositoryProvider = Provider<ApiAdminRepository>((ref) {
  return ApiAdminRepository(ref.watch(apiClientProvider));
});

/// Server-verified admin check backing the panel. Re-evaluates on login/logout.
final adminMeProvider = FutureProvider.autoDispose<String>((ref) async {
  ref.watch(authTokenStoreProvider.select((t) => t != null));
  return ref.watch(adminRepositoryProvider).me();
});
