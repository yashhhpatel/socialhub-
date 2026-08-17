import 'dart:convert';

import '../../../core/storage/key_value_store.dart';

/// The non-secret identity fields of a session (everything except the
/// tokens, which core/network's auth_token_store owns). Persisting these
/// lets the app restore the authenticated UI state — the header profile,
/// the org context — after a page reload without a round trip.
class SessionProfile {
  const SessionProfile({
    required this.userId,
    required this.email,
    required this.role,
    required this.orgId,
  });

  final String userId;
  final String email;
  final String role;
  final String orgId;
}

const _storageKey = 'sh_profile';

/// localStorage-backed persistence for the signed-in user's profile.
class SessionProfileStore {
  const SessionProfileStore._();

  static void save(SessionProfile profile) {
    KeyValueStore.write(
      _storageKey,
      jsonEncode({
        'userId': profile.userId,
        'email': profile.email,
        'role': profile.role,
        'orgId': profile.orgId,
      }),
    );
  }

  static SessionProfile? read() {
    final raw = KeyValueStore.read(_storageKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SessionProfile(
        userId: map['userId'] as String,
        email: map['email'] as String,
        role: map['role'] as String,
        orgId: map['orgId'] as String,
      );
    } catch (_) {
      KeyValueStore.remove(_storageKey);
      return null;
    }
  }

  static void clear() => KeyValueStore.remove(_storageKey);
}
