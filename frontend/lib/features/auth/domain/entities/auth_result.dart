import 'auth_session.dart';

/// Outcome of a register/login attempt.
///
/// Three outcomes: a session (success), an error message (failure), or — for
/// login when the account has MFA enabled (Phase 17.3) — an `mfaChallengeToken`
/// the caller exchanges with a second factor before a session is issued.
///
/// This is intentionally a small, feature-local result type rather than a
/// dependency on `core/error/failure.dart` — that shared error model is
/// introduced in a later milestone (see docs/architecture — Flutter Web
/// Application Architecture, §8).
class AuthResult {
  const AuthResult._({this.session, this.errorMessage, this.mfaChallengeToken});

  factory AuthResult.success(AuthSession session) =>
      AuthResult._(session: session);

  factory AuthResult.failure(String message) =>
      AuthResult._(errorMessage: message);

  factory AuthResult.mfaRequired(String challengeToken) =>
      AuthResult._(mfaChallengeToken: challengeToken);

  final AuthSession? session;
  final String? errorMessage;
  final String? mfaChallengeToken;

  bool get isSuccess => session != null;
  bool get isMfaRequired => mfaChallengeToken != null;
}
