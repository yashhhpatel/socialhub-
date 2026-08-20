import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../data/repositories/api_auth_repository.dart';
import '../../data/session_profile_store.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Controls the login/register flow and holds session state.
///
/// Depends only on the `AuthRepository` interface (per the DI rule in the
/// architecture doc) — it has no idea whether it's talking to the mock
/// repository or the real API repository (as of Milestone 1.4,
/// `authRepositoryProvider` resolves to the real one).
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._ref)
      : super(const AuthState.unauthenticated()) {
    _restoreSession();
    _watchTokenStore();
  }

  final AuthRepository _repository;
  final Ref _ref;

  /// Keep the UI session in lock-step with the token store. When the
  /// AuthInterceptor clears the tokens because a session could not be
  /// refreshed (expired or revoked), reflect that here: drop the session and
  /// the persisted profile so the app shows a clean signed-out state (the
  /// header's Log in button, "log in to continue" prompts) instead of a
  /// stuck "authenticated" UI where every request silently 401s.
  void _watchTokenStore() {
    _ref.listen<AuthTokens?>(authTokenStoreProvider, (_, next) {
      if (next == null && state.status == AuthStatus.authenticated) {
        SessionProfileStore.clear();
        state = const AuthState.unauthenticated();
      }
    });
  }

  /// On startup, rebuild the authenticated session from what was persisted
  /// (tokens in core/network's store, profile in SessionProfileStore) so a
  /// page reload keeps the user signed in with full access — no re-login.
  /// Both halves must be present; otherwise stay unauthenticated.
  void _restoreSession() {
    final tokens = _ref.read(authTokenStoreProvider);
    final profile = SessionProfileStore.read();
    if (tokens == null || profile == null) return;

    state = AuthState.authenticated(
      AuthSession(
        userId: profile.userId,
        email: profile.email,
        role: profile.role,
        orgId: profile.orgId,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      ),
    );
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.loading();

    final result = await _repository.login(email: email, password: password);

    if (result.isSuccess) {
      _storeTokens(result.session!);
      state = AuthState.authenticated(result.session!);
    } else if (result.isMfaRequired) {
      // Hold the challenge token in state; the MFA screen reads it and calls
      // verifyMfa. No tokens are stored until the second factor passes.
      state = AuthState.mfaRequired(result.mfaChallengeToken!);
    } else {
      state = AuthState.error(result.errorMessage!);
    }
  }

  /// Second step of an MFA login (Phase 17.3): submit a TOTP/recovery code
  /// against the pending challenge. Returns null on success, or an error
  /// message the screen shows. A missing/expired challenge sends the user back
  /// to a clean signed-out state.
  Future<String?> verifyMfa(String code) async {
    final challengeToken = state.mfaChallengeToken;
    if (challengeToken == null) {
      state = const AuthState.unauthenticated();
      return 'Your login session expired. Please sign in again.';
    }

    final result =
        await _repository.verifyMfa(challengeToken: challengeToken, code: code);

    if (result.isSuccess) {
      _storeTokens(result.session!);
      state = AuthState.authenticated(result.session!);
      return null;
    }
    return result.errorMessage ?? 'That code is incorrect. Try again.';
  }

  /// Abandon a pending MFA challenge (user backs out) — return to signed-out.
  void cancelMfa() {
    if (state.status == AuthStatus.mfaRequired) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String orgName,
  }) async {
    state = const AuthState.loading();

    final result = await _repository.register(
      email: email,
      password: password,
      orgName: orgName,
    );

    if (result.isSuccess) {
      _storeTokens(result.session!);
      state = AuthState.authenticated(result.session!);
    } else {
      state = AuthState.error(result.errorMessage!);
    }
  }

  Future<void> logout() async {
    final currentSession = state.session;

    // Clear local state and the token store unconditionally — a user
    // should never be stuck "logged in" client-side just because the
    // server-side revocation call fails (ApiAuthRepository.logout()
    // already treats network failure there as best-effort, not fatal).
    if (currentSession != null) {
      await _repository.logout(currentSession.refreshToken);
    }
    _ref.read(authTokenStoreProvider.notifier).state = null;
    SessionProfileStore.clear();
    state = const AuthState.unauthenticated();
  }

  /// Clears an error state back to unauthenticated, e.g. after the user
  /// dismisses an error banner and starts editing the form again.
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState.unauthenticated();
    }
  }

  void _storeTokens(AuthSession session) {
    _ref.read(authTokenStoreProvider.notifier).state = AuthTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    SessionProfileStore.save(
      SessionProfile(
        userId: session.userId,
        email: session.email,
        role: session.role,
        orgId: session.orgId,
      ),
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref);
});
