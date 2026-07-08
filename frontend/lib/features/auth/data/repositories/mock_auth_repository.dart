import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Mock auth repository for Milestone 1.3.
///
/// Simulates realistic register/login behavior (duplicate email rejected,
/// wrong password rejected, network latency simulated) entirely in memory
/// — no HTTP calls. This lets the auth screens and state management be
/// built and tested end to end before the backend exists.
///
/// Replaced by a real `ApiAuthRepository` in Milestone 1.4. Because both
/// implement the same `AuthRepository` interface, that swap happens in one
/// place (the provider override below) with zero changes to screens or the
/// controller.
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

  String _randomId() => _random.nextInt(1 << 32).toRadixString(16);
}

/// DI wiring for this feature.
///
/// NOTE: per the architecture doc, repository wiring ultimately belongs in
/// a central `core/di/providers.dart`. That folder doesn't exist yet — no
/// milestone has created it. Keeping the provider here, feature-local, is
/// the minimal-scope choice for now; it should be moved into `core/di` in
/// whichever future milestone introduces that composition root, at which
/// point this line is a one-line relocation, not a redesign.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});
