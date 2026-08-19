import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/features/auth/data/repositories/api_account_repository.dart';
import 'package:socialhub/features/auth/domain/entities/account_action_result.dart';
import 'package:socialhub/features/auth/domain/repositories/account_repository.dart';
import 'package:socialhub/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:socialhub/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:socialhub/features/auth/presentation/screens/verify_email_screen.dart';

/// Records calls and returns a scripted result, so the widget tests can assert
/// both what the screen sent and how it renders each outcome.
class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(this._result);

  final AccountActionResult _result;
  String? verifiedToken;
  String? resetEmail;
  ({String token, String newPassword})? reset;
  bool resent = false;

  @override
  Future<AccountActionResult> verifyEmail(String token) async {
    verifiedToken = token;
    return _result;
  }

  @override
  Future<AccountActionResult> requestPasswordReset(String email) async {
    resetEmail = email;
    return _result;
  }

  @override
  Future<AccountActionResult> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    reset = (token: token, newPassword: newPassword);
    return _result;
  }

  @override
  Future<AccountActionResult> resendVerification() async {
    resent = true;
    return _result;
  }
}

// A tiny router so `context.go(...)` in the screens has somewhere to go.
Widget _host(Widget screen, _FakeAccountRepository repo) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN PAGE')),
      GoRoute(path: '/dashboard', builder: (_, __) => const Text('DASH PAGE')),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const Text('FORGOT PAGE'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [accountRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ForgotPasswordScreen', () {
    testWidgets('sends the email and shows the generic confirmation',
        (tester) async {
      final repo = _FakeAccountRepository(
        AccountActionResult.success('If an account exists, a link is on its way.'),
      );
      await tester.pumpWidget(_host(const ForgotPasswordScreen(), repo));

      await tester.enterText(find.byType(TextFormField), 'jane@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(repo.resetEmail, 'jane@example.com');
      expect(find.textContaining('on its way'), findsOneWidget);
      // Form is replaced by the confirmation — no more email field.
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('validates the email before calling the backend',
        (tester) async {
      final repo = _FakeAccountRepository(AccountActionResult.success());
      await tester.pumpWidget(_host(const ForgotPasswordScreen(), repo));

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(repo.resetEmail, isNull);
      expect(find.text('Enter a valid email.'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('rejects a link with no token', (tester) async {
      final repo = _FakeAccountRepository(AccountActionResult.success());
      await tester.pumpWidget(_host(const ResetPasswordScreen(token: null), repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('missing its token'), findsOneWidget);
      expect(find.text('Reset password'), findsNothing);
    });

    testWidgets('submits the new password with the URL token', (tester) async {
      final repo = _FakeAccountRepository(
        AccountActionResult.success('Your password has been reset.'),
      );
      await tester.pumpWidget(
        _host(const ResetPasswordScreen(token: 'tok_123'), repo),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'NewPass1!');
      await tester.enterText(fields.at(1), 'NewPass1!');
      await tester.tap(find.text('Reset password'));
      await tester.pumpAndSettle();

      expect(repo.reset?.token, 'tok_123');
      expect(repo.reset?.newPassword, 'NewPass1!');
      expect(find.textContaining('has been reset'), findsOneWidget);
    });

    testWidgets('blocks submit when confirmation does not match',
        (tester) async {
      final repo = _FakeAccountRepository(AccountActionResult.success());
      await tester.pumpWidget(
        _host(const ResetPasswordScreen(token: 'tok_123'), repo),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'NewPass1!');
      await tester.enterText(fields.at(1), 'Different1!');
      await tester.tap(find.text('Reset password'));
      await tester.pumpAndSettle();

      expect(repo.reset, isNull);
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });

  group('VerifyEmailScreen', () {
    testWidgets('auto-verifies the URL token and shows success',
        (tester) async {
      final repo = _FakeAccountRepository(
        AccountActionResult.success('Your email has been verified.'),
      );
      await tester.pumpWidget(_host(const VerifyEmailScreen(token: 'vtok'), repo));
      await tester.pumpAndSettle();

      expect(repo.verifiedToken, 'vtok');
      expect(find.textContaining('has been verified'), findsOneWidget);
    });

    testWidgets('shows an error state for a bad token', (tester) async {
      final repo = _FakeAccountRepository(
        AccountActionResult.failure('This link is invalid or has expired.'),
      );
      await tester.pumpWidget(_host(const VerifyEmailScreen(token: 'bad'), repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('invalid or has expired'), findsOneWidget);
    });

    testWidgets('reports a missing token without calling the backend',
        (tester) async {
      final repo = _FakeAccountRepository(AccountActionResult.success());
      await tester.pumpWidget(_host(const VerifyEmailScreen(token: null), repo));
      await tester.pumpAndSettle();

      expect(repo.verifiedToken, isNull);
      expect(find.textContaining('missing its token'), findsOneWidget);
    });
  });
}
