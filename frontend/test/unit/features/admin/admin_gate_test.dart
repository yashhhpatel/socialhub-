import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/core/network/auth_token_store.dart';
import 'package:socialhub/features/admin/data/api_admin_repository.dart';
import 'package:socialhub/features/admin/domain/admin_overview.dart';
import 'package:socialhub/features/admin/presentation/screens/admin_overview_screen.dart';
import 'package:socialhub/features/admin/presentation/widgets/admin_shell.dart';

const _loggedIn = AuthTokens(accessToken: 'a', refreshToken: 'r');

AdminOverview _overview() => const AdminOverview(
      totalOrganizations: 7,
      totalUsers: 12,
      newOrganizations30d: 3,
      newUsers30d: 5,
      activeOrganizations: 4,
      planDistribution: [PlanCount(tier: 'free', count: 5)],
      connectedAccounts: 6,
      accountsNeedingReconnect: 1,
      publishedPosts: 30,
      failedPosts: 2,
      publishFailureRate: 0.0625,
      unverifiedUsers: 2,
      mfaEnabledUsers: 1,
    );

Widget _host(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/admin',
    routes: [
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminShell(
          selectedPath: '/admin',
          child: AdminOverviewScreen(),
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
  testWidgets('platform admin sees the admin shell + overview KPIs',
      (tester) async {
    await tester.pumpWidget(_host(<Override>[
      authTokenStoreProvider.overrideWith((ref) => _loggedIn),
      adminMeProvider.overrideWith((ref) async => 'admin@socialhub.dev'),
      adminOverviewProvider.overrideWith((ref) async => _overview()),
    ],),);
    await tester.pumpAndSettle();

    expect(find.text('SocialHub Admin'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('admin@socialhub.dev'), findsOneWidget);
    // KPI values render from the overview.
    expect(find.text('Organizations'), findsOneWidget);
    expect(find.text('7'), findsWidgets); // totalOrganizations
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
