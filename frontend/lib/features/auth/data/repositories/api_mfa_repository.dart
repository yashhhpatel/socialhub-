import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

/// Result of starting MFA enrollment (POST /auth/mfa/setup).
class MfaSetup {
  const MfaSetup({required this.secret, required this.otpauthUri});
  final String secret;
  final String otpauthUri;
}

/// Manages TOTP MFA for the signed-in user (Phase 17.3): enrollment and
/// removal. The login second step lives in AuthRepository.verifyMfa; this is
/// the authenticated management surface used from Settings. Uses the shared
/// authenticated Dio so the JWT is attached automatically.
class ApiMfaRepository {
  ApiMfaRepository(this._dio);

  final Dio _dio;

  /// Begin enrollment — returns the secret + otpauth URI to show as a QR.
  Future<MfaSetup> setup() async {
    final response = await _dio.post<Map<String, dynamic>>('/auth/mfa/setup');
    final data = response.data!;
    return MfaSetup(
      secret: data['secret'] as String,
      otpauthUri: data['otpauthUri'] as String,
    );
  }

  /// Finish enrollment by verifying a code. Returns the one-time recovery
  /// codes on success; throws [MfaException] with a user-facing message on a
  /// bad code.
  Future<List<String>> enable(String code) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/mfa/enable',
        data: {'code': code},
      );
      return (response.data!['recoveryCodes'] as List)
          .map((c) => c as String)
          .toList();
    } on DioException catch (e) {
      throw MfaException(_extractErrorMessage(e));
    }
  }

  /// Turn MFA off — requires a valid current code. Throws [MfaException] on a
  /// bad code.
  Future<void> disable(String code) async {
    try {
      await _dio.post<void>('/auth/mfa/disable', data: {'code': code});
    } on DioException catch (e) {
      throw MfaException(_extractErrorMessage(e));
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
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Check your connection and try again.'
          '${kDebugMode ? '\n[DEV] ${e.type.name} · ${e.requestOptions.uri}' : ''}';
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Thrown by [ApiMfaRepository] for expected, user-facing failures (wrong code).
class MfaException implements Exception {
  const MfaException(this.message);
  final String message;
  @override
  String toString() => message;
}

final mfaRepositoryProvider = Provider<ApiMfaRepository>((ref) {
  return ApiMfaRepository(ref.watch(apiClientProvider));
});
