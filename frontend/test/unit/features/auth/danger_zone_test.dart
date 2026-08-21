import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/features/auth/data/repositories/api_account_management_repository.dart';
import 'package:socialhub/features/auth/data/repositories/api_auth_repository.dart';
import 'package:socialhub/features/auth/domain/entities/auth_result.dart';
import 'package:socialhub/features/auth/domain/repositories/auth_repository.dart';
import 'package:socialhub/features/auth/presentation/widgets/danger_zone_card.dart';

/// Fake account-management repo: records calls and returns scripted results.
class _FakeMgmtRepo extends ApiAccountManagementRepository {
  _FakeMgmtRepo({this.throwOnDelete}) : super(Dio());

  final String? throwOnDelete;
  bool exportCalled = false;
  String? deletedWithPassword;

  @override
  Future<Map<String, dynamic>> exportData() async {
    exportCalled = true;
    return {'account': {'email': 'jane@example.com'}};
  }

  @override
  Future<String> deleteAccount(String password) async {
    if (throwOnDelete != null) {
      throw AccountManagementException(throwOnDelete!);
    }
    deletedWithPassword = password;
    return 'user';
  }
}

/// No-op auth repo so the post-delete logout() never touches the network.
class _NoopAuthRepo implements AuthRepository {
  @override
  Future<AuthResult> login({required String email, required String password}) async =>
      AuthResult.failure('x');
  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) async =>
      AuthResult.failure('x');
  @override
  Future<AuthResult> verifyMfa({
    required String challengeToken,
    required String code,
  }) async =>
      AuthResult.failure('x');
  @override
  Future<void> logout(String refreshToken) async {}
}

Widget _host(_FakeMgmtRepo repo) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: DangerZoneCard()),
      ),
      GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
    ],
  );
  return ProviderScope(
    overrides: [
      accountManagementRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(_NoopAuthRepo()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('Export downloads and confirms via a snackbar', (tester) async {
    final repo = _FakeMgmtRepo();
    await tester.pumpWidget(_host(repo));

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(repo.exportCalled, isTrue);
    expect(find.textContaining('downloaded'), findsOneWidget);
  });

  testWidgets('Delete requires a password before calling the backend',
      (tester) async {
    final repo = _FakeMgmtRepo();
    await tester.pumpWidget(_host(repo));

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirm dialog is open; submit with no password.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your password to confirm.'), findsOneWidget);
    expect(repo.deletedWithPassword, isNull);
  });

  testWidgets('Delete with a password calls the backend', (tester) async {
    final repo = _FakeMgmtRepo();
    await tester.pumpWidget(_host(repo));

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'MyPassw0rd!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(repo.deletedWithPassword, 'MyPassw0rd!');
  });

  testWidgets('A wrong password surfaces the error, no navigation',
      (tester) async {
    final repo = _FakeMgmtRepo(throwOnDelete: 'Password is incorrect.');
    await tester.pumpWidget(_host(repo));

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Password is incorrect.'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });
}
