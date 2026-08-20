import '../../domain/entities/auth_session.dart';

enum AuthStatus {
  unauthenticated,
  loading,
  authenticated,
  error,
  // Password accepted but a second factor is still required (Phase 17.3).
  mfaRequired,
}

/// State held by AuthController. Screens branch on `status`, never on
/// parsing an error string or null-checking fields ad hoc.
class AuthState {
  const AuthState._({
    required this.status,
    this.session,
    this.errorMessage,
    this.mfaChallengeToken,
  });

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  const AuthState.loading() : this._(status: AuthStatus.loading);

  const AuthState.authenticated(AuthSession session)
      : this._(status: AuthStatus.authenticated, session: session);

  const AuthState.error(String message)
      : this._(status: AuthStatus.error, errorMessage: message);

  const AuthState.mfaRequired(String challengeToken)
      : this._(
          status: AuthStatus.mfaRequired,
          mfaChallengeToken: challengeToken,
        );

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
  final String? mfaChallengeToken;
}
