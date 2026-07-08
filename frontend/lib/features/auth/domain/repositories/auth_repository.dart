import '../entities/auth_result.dart';

/// Auth repository contract.
///
/// Per docs/architecture — Flutter Web Application Architecture, §3
/// (Dependency Injection): interfaces live in domain/, implementations live
/// in data/. `AuthController` depends only on this interface.
///
/// Backed by `MockAuthRepository` for this milestone; a real
/// `ApiAuthRepository` (calling POST /auth/register, POST /auth/login per
/// docs/api/SocialHub_REST_API_Design.md) is introduced in Milestone 1.4
/// without requiring any change to this contract or to the screens that
/// use it.
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
}
