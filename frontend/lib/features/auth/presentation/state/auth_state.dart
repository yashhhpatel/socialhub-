import '../../domain/entities/auth_session.dart';

enum AuthStatus { unauthenticated, loading, authenticated, error }

/// State held by AuthController. Screens branch on `status`, never on
/// parsing an error string or null-checking fields ad hoc.
class AuthState {
  const AuthState._({
    required this.status,
    this.session,
    this.errorMessage,
  });

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  const AuthState.loading() : this._(status: AuthStatus.loading);

  const AuthState.authenticated(AuthSession session)
      : this._(status: AuthStatus.authenticated, session: session);

  const AuthState.error(String message)
      : this._(status: AuthStatus.error, errorMessage: message);

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
}
