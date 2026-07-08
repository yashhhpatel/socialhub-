import 'auth_session.dart';

/// Outcome of a register/login attempt.
///
/// This is intentionally a small, feature-local result type rather than a
/// dependency on `core/error/failure.dart` — that shared error model is
/// introduced in a later milestone (see docs/architecture — Flutter Web
/// Application Architecture, §8). When it lands, this can be migrated to
/// use it; presentation code here only depends on the two named
/// constructors below, so that migration is a small, contained change.
class AuthResult {
  const AuthResult._({this.session, this.errorMessage})
      : assert(
          (session != null) != (errorMessage != null),
          'AuthResult must have exactly one of session or errorMessage',
        );

  factory AuthResult.success(AuthSession session) =>
      AuthResult._(session: session);

  factory AuthResult.failure(String message) =>
      AuthResult._(errorMessage: message);

  final AuthSession? session;
  final String? errorMessage;

  bool get isSuccess => session != null;
}
