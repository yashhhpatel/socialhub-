import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/features/auth/data/repositories/api_auth_repository.dart';
import 'package:socialhub/features/auth/domain/entities/auth_result.dart';
import 'package:socialhub/features/auth/domain/entities/auth_session.dart';
import 'package:socialhub/features/auth/domain/repositories/auth_repository.dart';
import 'package:socialhub/features/auth/presentation/screens/mfa_challenge_screen.dart';
import 'package:socialhub/features/auth/presentation/state/auth_controller.dart';
import 'package:socialhub/features/auth/presentation/state/auth_state.dart';

/// Scriptable AuthRepository: login returns a challenge, verifyMfa returns a
/// scripted result, so we can drive the whole MFA login without a backend.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.verifyResult});

  final AuthResult verifyResult;
  String? verifiedChallenge;
  String? verifiedCode;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async =>
      AuthResult.mfaRequired('challenge-token-abc');

  @override
  Future<AuthResult> verifyMfa({
    required String challengeToken,
    required String code,
  }) async {
    verifiedChallenge = challengeToken;
    verifiedCode = code;
    return verifyResult;
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) async =>
      AuthResult.failure('not used');

  @override
  Future<void> logout(String refreshToken) async {}
}

AuthSession _session() => const AuthSession(
      userId: 'u1',
      email: 'jane@example.com',
      role: 'owner',
      orgId: 'org_1',
      accessToken: 'access',
      refreshToken: 'refresh',
    );

void main() {
  group('AuthController MFA branch', () {
    test('login with an MFA account moves to mfaRequired, not authenticated',
        () async {
      final repo = _FakeAuthRepository(
        verifyResult: AuthResult.success(_session()),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'jane@example.com', password: 'pw');

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.mfaRequired,
      );
      expect(
        container.read(authControllerProvider).mfaChallengeToken,
        'challenge-token-abc',
      );
    });

    test('verifyMfa success authenticates and forwards the challenge token',
        () async {
      final repo = _FakeAuthRepository(
        verifyResult: AuthResult.success(_session()),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.login(email: 'jane@example.com', password: 'pw');
      final error = await notifier.verifyMfa('123456');

      expect(error, isNull);
      expect(repo.verifiedChallenge, 'challenge-token-abc');
      expect(repo.verifiedCode, '123456');
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
    });

    test('verifyMfa failure returns the message and stays on the challenge',
        () async {
      final repo = _FakeAuthRepository(
        verifyResult: AuthResult.failure('That code is incorrect. Try again.'),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.login(email: 'jane@example.com', password: 'pw');
      final error = await notifier.verifyMfa('000000');

      expect(error, 'That code is incorrect. Try again.');
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.mfaRequired,
      );
    });

    test('verifyMfa with no pending challenge resets to unauthenticated',
        () async {
      final repo = _FakeAuthRepository(
        verifyResult: AuthResult.success(_session()),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // No prior login → no challenge token in state.
      final error =
          await container.read(authControllerProvider.notifier).verifyMfa('1');

      expect(error, contains('expired'));
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });
  });

  group('MfaChallengeScreen', () {
    Widget host(_FakeAuthRepository repo) {
      final router = GoRouter(
        initialLocation: '/mfa-challenge',
        routes: [
          GoRoute(
            path: '/mfa-challenge',
            builder: (_, __) => const MfaChallengeScreen(),
          ),
          GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
          GoRoute(path: '/dashboard', builder: (_, __) => const Text('DASH')),
        ],
      );
      return ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('shows an error on a wrong code and stays put', (tester) async {
      final repo = _FakeAuthRepository(
        verifyResult: AuthResult.failure('That code is incorrect. Try again.'),
      );
      await tester.pumpWidget(host(repo));
      // Put a pending challenge in state by logging in first.
      final ctx = tester.element(find.byType(MfaChallengeScreen));
      final container = ProviderScope.containerOf(ctx);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'jane@example.com', password: 'pw');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.textContaining('incorrect'), findsOneWidget);
    });
  });
}
