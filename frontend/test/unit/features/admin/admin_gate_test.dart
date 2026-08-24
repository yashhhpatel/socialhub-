import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/core/network/auth_token_store.dart';
import 'package:socialhub/features/admin/data/api_admin_repository.dart';
import 'package:socialhub/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:socialhub/features/admin/presentation/widgets/admin_shell.dart';

const _loggedIn = AuthTokens(accessToken: 'a', refreshToken: 'r');

Widget _host(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/admin',
    routes: [
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminShell(
          selectedPath: '/admin',
          child: AdminHomeScreen(),
        ),
      ),
      GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
      GoRoute(path: '/', builder: (_, __) => const Text('APP HOME')),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

DioException _forbidden() => DioException(
      requestOptions: RequestOptions(path: '/admin/me'),
      response: Response(
        requestOptions: RequestOptions(path: '/admin/me'),
        statusCode: 403,
      ),
    );

void main() {
  testWidgets('platform admin sees the admin shell', (tester) async {
    await tester.pumpWidget(_host(<Override>[
      authTokenStoreProvider.overrideWith((ref) => _loggedIn),
      adminMeProvider.overrideWith((ref) async => 'admin@socialhub.dev'),
    ],),);
    await tester.pumpAndSettle();

    expect(find.text('SocialHub Admin'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('admin@socialhub.dev'), findsOneWidget);
  });

  testWidgets('logged-in non-admin is blocked (403 → Not authorized)',
      (tester) async {
    await tester.pumpWidget(_host(<Override>[
      authTokenStoreProvider.overrideWith((ref) => _loggedIn),
      adminMeProvider.overrideWith((ref) async => throw _forbidden()),
    ],),);
    await tester.pumpAndSettle();

    expect(find.text('Not authorized'), findsOneWidget);
    expect(find.text('SocialHub Admin'), findsNothing);
  });

  testWidgets('logged-out visitor is asked to sign in', (tester) async {
    await tester.pumpWidget(_host(<Override>[
      authTokenStoreProvider.overrideWith((ref) => null),
    ],),);
    await tester.pumpAndSettle();

    expect(find.text('Admin sign-in required'), findsOneWidget);
    expect(find.text('SocialHub Admin'), findsNothing);
  });
}
