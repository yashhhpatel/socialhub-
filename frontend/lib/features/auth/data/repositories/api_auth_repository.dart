import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// Real AuthRepository, calling the NestJS backend per
/// docs/api/SocialHub_REST_API_Design.md, §2 (Auth). Implements the exact
/// same interface MockAuthRepository did — see auth_repository.dart for
/// why that swap needed no changes to AuthController or the screens.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String orgName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email, 'password': password, 'orgName': orgName},
      );
      return AuthResult.success(_sessionFromResponse(response.data!));
    } on DioException catch (e) {
      return AuthResult.failure(_extractErrorMessage(e));
    }
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthResult.success(_sessionFromResponse(response.data!));
    } on DioException catch (e) {
      return AuthResult.failure(_extractErrorMessage(e));
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>('/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException {
      // Best-effort: per AuthController.logout(), the app logs the user
      // out locally regardless of whether this network call succeeds — a
      // user should never be stuck "logged in" just because a logout
      // request failed to reach the server.
    }
  }

  AuthSession _sessionFromResponse(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    return AuthSession(
      userId: user['id'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
      orgId: user['orgId'] as String,
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  /// Maps the backend's standard error envelope (see
  /// docs/api/SocialHub_REST_API_Design.md, §0) to a user-facing string.
  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;

    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }

    // NestJS's ValidationPipe can emit `message` as an array of per-field
    // strings under some configurations — handled defensively even though
    // our current global pipe config emits a single string.
    if (data is Map && data['message'] is List) {
      final messages = data['message'] as List;
      if (messages.isNotEmpty) return messages.first.toString();
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Check your connection and try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}

/// authRepositoryProvider now resolves here instead of MockAuthRepository
/// — the swap documented as a "one-line change" back in Milestone 1.3.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(ref.watch(apiClientProvider));
});
