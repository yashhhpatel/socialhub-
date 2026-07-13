import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Access + refresh token pair currently held by the app.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Where the current session's tokens live, in memory.
///
/// Deliberately lives in `core/network`, not `features/auth` — per
/// docs/architecture — Flutter Web Application Architecture, §3: a
/// feature may depend on core/, core/ never depends on a feature.
/// AuthInterceptor (this folder) reads from this provider on every
/// request; features/auth/presentation/state/auth_controller.dart writes
/// to it after login/register/refresh/logout. That keeps the dependency
/// pointing one direction only.
///
/// In-memory only, same as theme_mode_controller.dart's documented
/// limitation from Milestone 0.2: persistence across a page reload needs
/// `core/storage`, which doesn't exist yet. Until then, a hard refresh of
/// the browser tab logs the user out — an accepted, temporary gap, not an
/// oversight.
final authTokenStoreProvider = StateProvider<AuthTokens?>((ref) => null);
