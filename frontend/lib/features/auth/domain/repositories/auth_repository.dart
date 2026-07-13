import '../entities/auth_result.dart';

/// Auth repository contract.
///
/// Per docs/architecture — Flutter Web Application Architecture, §3
/// (Dependency Injection): interfaces live in domain/, implementations live
/// in data/. `AuthController` depends only on this interface.
///
/// Backed by `MockAuthRepository` through Milestone 1.3. As of Milestone
/// 1.4, `authRepositoryProvider` resolves to the real `ApiAuthRepository`
/// instead (see data/repositories/api_auth_repository.dart) — register()
/// and login() needed no contract changes to make that swap, exactly as
/// planned. `logout()` is the one honest exception: it wasn't in this
/// interface as of 1.3, because revoking a specific refresh token
/// server-side wasn't meaningful against a mock backend. It's added now
/// because the real backend's POST /auth/logout does something real.
abstract class AuthRepository {
  Future<AuthResult> register({
    required String email,
    required String password,
    required String orgName,
  });

  Future<AuthResult> login({
    required String email,
    required String password,
  });

  Future<void> logout(String refreshToken);
}
