import 'dart:math';

import '../../domain/entities/auth_result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// In-memory fake backing store, scoped to this repository instance.
class _MockUserRecord {
  _MockUserRecord({
    required this.userId,
    required this.email,
    required this.password,
    required this.orgId,
  });

  final String userId;
  final String email;
  final String password;
  final String orgId;
}

/// Mock auth repository, used as the active `authRepositoryProvider`
/// through Milestone 1.3.
///
/// As of Milestone 1.4, `authRepositoryProvider` resolves to the real
/// `ApiAuthRepository` instead (see api_auth_repository.dart) — this class
/// is kept, unused by the provider but still a complete, correct
/// `AuthRepository` implementation, as a fast networkless fake available
/// for future widget/unit tests that shouldn't depend on a running
/// backend.
class MockAuthRepository implements AuthRepository {
  final Map<String, _MockUserRecord> _usersByEmail = {};
  final Random _random = Random();

  static const _simulatedLatency = Duration(milliseconds: 600);

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String orgName,
  }) async {
    await Future<void>.delayed(_simulatedLatency);

    final normalizedEmail = email.trim().toLowerCase();

    if (_usersByEmail.containsKey(normalizedEmail)) {
      return AuthResult.failure('An account with this email already exists.');
    }

    final userId = 'usr_${_randomId()}';
    final orgId = 'org_${_randomId()}';

    _usersByEmail[normalizedEmail] = _MockUserRecord(
      userId: userId,
      email: normalizedEmail,
      password: password,
      orgId: orgId,
    );

    return AuthResult.success(
      AuthSession(
        userId: userId,
        email: normalizedEmail,
        role: 'owner',
        orgId: orgId,
        accessToken: 'mock_access_${_randomId()}',
        refreshToken: 'mock_refresh_${_randomId()}',
      ),
    );
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_simulatedLatency);

    final normalizedEmail = email.trim().toLowerCase();
    final record = _usersByEmail[normalizedEmail];

    // Deliberately generic message — mirrors the real backend's rule
    // (see docs/api/SocialHub_REST_API_Design.md, POST /auth/login) of
    // never revealing whether the email exists.
    if (record == null || record.password != password) {
      return AuthResult.failure('Invalid email or password.');
    }

    return AuthResult.success(
      AuthSession(
        userId: record.userId,
        email: record.email,
        role: 'owner',
        orgId: record.orgId,
        accessToken: 'mock_access_${_randomId()}',
        refreshToken: 'mock_refresh_${_randomId()}',
      ),
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    // No-op: the mock doesn't track live refresh-token validity state the
    // way the real backend's refresh_token table does, so there's nothing
    // meaningful to revoke here. Kept as a real (not throwing) method so
    // this class still satisfies AuthRepository for any future test that
    // wants a fast, networkless fake.
    await Future<void>.delayed(_simulatedLatency);
  }

  String _randomId() => _random.nextInt(1 << 32).toRadixString(16);
}
