import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Controls the login/register flow and holds session state.
///
/// Depends only on the `AuthRepository` interface (per the DI rule in the
/// architecture doc) — it has no idea whether it's talking to the mock
/// repository (this milestone) or the real API repository (Milestone 1.4).
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState.unauthenticated());

  final AuthRepository _repository;

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.loading();

    final result = await _repository.login(email: email, password: password);

    state = result.isSuccess
        ? AuthState.authenticated(result.session!)
        : AuthState.error(result.errorMessage!);
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

    state = result.isSuccess
        ? AuthState.authenticated(result.session!)
        : AuthState.error(result.errorMessage!);
  }

  void logout() {
    state = const AuthState.unauthenticated();
  }

  /// Clears an error state back to unauthenticated, e.g. after the user
  /// dismisses an error banner and starts editing the form again.
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState.unauthenticated();
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
