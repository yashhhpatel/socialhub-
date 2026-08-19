import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/account_action_result.dart';
import '../../domain/repositories/account_repository.dart';

/// Real [AccountRepository], calling the NestJS auth endpoints added in
/// Phase 17.1. Uses the shared authenticated Dio (apiClientProvider): the
/// public endpoints simply ignore the Authorization header, while
/// resendVerification needs it.
class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._dio);

  final Dio _dio;

  @override
  Future<AccountActionResult> verifyEmail(String token) async {
    try {
      await _dio.post<void>('/auth/verify-email', data: {'token': token});
      return AccountActionResult.success('Your email has been verified.');
    } on DioException catch (e) {
      return AccountActionResult.failure(_extractErrorMessage(e));
    }
  }

  @override
  Future<AccountActionResult> requestPasswordReset(String email) async {
    try {
      await _dio.post<void>(
        '/auth/password-reset/request',
        data: {'email': email},
      );
    } on DioException catch (e) {
      // Only a genuine transport failure should surface — a 4xx here would
      // itself leak nothing useful, but the backend is designed to 202 for
      // any syntactically valid email, so treat validation errors as the
      // only failure worth showing.
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return AccountActionResult.failure(_extractErrorMessage(e));
      }
      if ((e.response?.statusCode ?? 0) >= 400 &&
          (e.response?.statusCode ?? 0) < 500) {
        return AccountActionResult.failure(_extractErrorMessage(e));
      }
    }
    // Deliberately identical response whether or not the account exists.
    return AccountActionResult.success(
      'If an account exists for that email, a password reset link is on its way.',
    );
  }

  @override
  Future<AccountActionResult> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        '/auth/password-reset',
        data: {'token': token, 'newPassword': newPassword},
      );
      return AccountActionResult.success(
        'Your password has been reset. You can now log in.',
      );
    } on DioException catch (e) {
      return AccountActionResult.failure(_extractErrorMessage(e));
    }
  }

  @override
  Future<AccountActionResult> resendVerification() async {
    try {
      await _dio.post<void>('/auth/verify-email/resend');
      return AccountActionResult.success('Verification email sent.');
    } on DioException catch (e) {
      return AccountActionResult.failure(_extractErrorMessage(e));
    }
  }

  /// Same error-envelope mapping as ApiAuthRepository (see its doc comment).
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
          '${_debugSuffix(e)}';
    }
    return 'Something went wrong. Please try again.${_debugSuffix(e)}';
  }

  String _debugSuffix(DioException e) {
    if (!kDebugMode) return '';
    final status = e.response?.statusCode;
    final url = e.requestOptions.uri;
    return '\n[DEV] ${e.type.name}'
        '${status != null ? ' · HTTP $status' : ''}'
        ' · $url'
        '${e.message != null ? ' · ${e.message}' : ''}';
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return ApiAccountRepository(ref.watch(apiClientProvider));
});
