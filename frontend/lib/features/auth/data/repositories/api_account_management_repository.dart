import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

/// Authenticated account-management operations for the signed-in user
/// (Phase 17.4): GDPR data export and permanent account deletion. Uses the
/// shared authenticated Dio so the JWT is attached automatically.
class ApiAccountManagementRepository {
  ApiAccountManagementRepository(this._dio);

  final Dio _dio;

  /// Fetches the full data-export snapshot as a JSON map.
  Future<Map<String, dynamic>> exportData() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me/export');
    return response.data!;
  }

  /// Permanently deletes the account after re-confirming the password. Returns
  /// the deletion scope ('organization' for an owner, 'user' for a member).
  /// Throws [AccountManagementException] with a user-facing message on a bad
  /// password.
  Future<String> deleteAccount(String password) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/users/me',
        data: {'password': password},
      );
      return response.data?['scope'] as String? ?? 'user';
    } on DioException catch (e) {
      throw AccountManagementException(_extractErrorMessage(e));
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (data is Map && data['message'] is List) {
      final messages = data['message'] as List;
      if (messages.isNotEmpty) return messages.first.toString();
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Thrown for expected, user-facing failures (e.g. a wrong password on delete).
class AccountManagementException implements Exception {
  const AccountManagementException(this.message);
  final String message;
  @override
  String toString() => message;
}

final accountManagementRepositoryProvider =
    Provider<ApiAccountManagementRepository>((ref) {
  return ApiAccountManagementRepository(ref.watch(apiClientProvider));
});
