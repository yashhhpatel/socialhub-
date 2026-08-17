import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';

/// Access + refresh token pair currently held by the app.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

const _storageKey = 'sh_tokens';

/// Where the current session's tokens live.
///
/// Deliberately lives in `core/network`, not `features/auth` — per
/// docs/architecture — Flutter Web Application Architecture, §3: a
/// feature may depend on core/, core/ never depends on a feature.
/// AuthInterceptor (this folder) reads from this provider on every
/// request; features/auth/presentation/state/auth_controller.dart writes
/// to it after login/register/refresh/logout. That keeps the dependency
/// pointing one direction only.
///
/// Persisted to localStorage so a page reload keeps the user signed in
/// (previously the tokens were in-memory only, so a hard refresh logged
/// them out). The interceptor's silent token rotation writes through here
/// too, so the freshest tokens always survive a reload. Standard SPA
/// trade-off: localStorage is readable by any script on the origin, so this
/// relies on the app being XSS-free.
final authTokenStoreProvider = StateProvider<AuthTokens?>((ref) {
  // listenSelf keeps every writer (login, logout, and the interceptor's
  // silent token rotation) persisting through one place, instead of four
  // call sites each remembering to save.
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => _persist(next));
  return _restore();
});

void _persist(AuthTokens? tokens) {
  if (tokens == null) {
    KeyValueStore.remove(_storageKey);
    return;
  }
  KeyValueStore.write(
    _storageKey,
    jsonEncode({
      'accessToken': tokens.accessToken,
      'refreshToken': tokens.refreshToken,
    }),
  );
}

AuthTokens? _restore() {
  final raw = KeyValueStore.read(_storageKey);
  if (raw == null) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return AuthTokens(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
    );
  } catch (_) {
    // Corrupt/legacy value — drop it rather than crashing on startup.
    KeyValueStore.remove(_storageKey);
    return null;
  }
}
