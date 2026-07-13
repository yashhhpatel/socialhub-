import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../data/repositories/api_auth_repository.dart';
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
      : super(const AuthState.unauthenticated());

  final AuthRepository _repository;
  final Ref _ref;

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.loading();

    final result = await _repository.login(email: email, password: password);

    if (result.isSuccess) {
      _storeTokens(result.session!);
      state = AuthState.authenticated(result.session!);
    } else {
      state = AuthState.error(result.errorMessage!);
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
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider), ref);
});
