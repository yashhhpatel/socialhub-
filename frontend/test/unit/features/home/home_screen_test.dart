import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/core/network/auth_token_store.dart';
import 'package:socialhub/features/dashboard/data/api_dashboard_repository.dart';
import 'package:socialhub/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:socialhub/features/home/presentation/screens/home_screen.dart';

DashboardSummary _summary() => const DashboardSummary(
      scheduledPosts: 3,
      publishedPosts: 7,
      drafts: 2,
      connectedAccounts: 1,
      aiCreditsUsed: 10,
      aiCreditsTotal: 500,
      recentActivity: [],
    );

DioException _unauthorized() => DioException(
      requestOptions: RequestOptions(path: '/dashboard/summary'),
      response: Response(
        requestOptions: RequestOptions(path: '/dashboard/summary'),
        statusCode: 401,
      ),
    );

Widget _marker(String t) => Scaffold(body: Center(child: Text(t)));

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: SingleChildScrollView(child: HomeScreen())),
        ),
        GoRoute(path: '/register', builder: (_, __) => _marker('REGISTER')),
        GoRoute(path: '/login', builder: (_, __) => _marker('LOGIN')),
        GoRoute(path: '/content', builder: (_, __) => _marker('CONTENT')),
        GoRoute(path: '/dashboard', builder: (_, __) => _marker('DASHBOARD')),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  required bool loggedIn,
}) async {
  tester.view.physicalSize = const Size(1400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authTokenStoreProvider.overrideWith(
          (ref) => loggedIn
              ? const AuthTokens(accessToken: 't', refreshToken: 'r')
              : null,
        ),
        dashboardSummaryProvider.overrideWith(
          (ref) async => loggedIn ? _summary() : throw _unauthorized(),
        ),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out: welcome + CTAs + sign-in overview + quick nav',
      (tester) async {
    await _pump(tester, loggedIn: false);

    expect(find.text('Welcome to SocialHub'), findsOneWidget);
    expect(find.text('Get started free'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Log in'), findsOneWidget);

    // Overview needs an account -> sign-in prompt, not fake numbers.
    expect(find.text('Sign in to see your overview'), findsOneWidget);

    // Quick-navigation cards.
    expect(find.text('Quick navigation'), findsOneWidget);
    expect(find.text('Content', skipOffstage: false), findsOneWidget);
    expect(find.text('Analytics', skipOffstage: false), findsOneWidget);
  });

  testWidgets('signed out: Get started routes to register', (tester) async {
    await _pump(tester, loggedIn: false);
    await tester.tap(find.text('Get started free'));
    await tester.pumpAndSettle();
    expect(find.text('REGISTER'), findsOneWidget);
  });

  testWidgets('signed out: a quick-nav card routes into its page',
      (tester) async {
    await _pump(tester, loggedIn: false);
    await tester.ensureVisible(find.text('Content'));
    await tester.tap(find.text('Content'));
    await tester.pumpAndSettle();
    expect(find.text('CONTENT'), findsOneWidget);
  });

  testWidgets('signed in: real-data overview cards from the summary',
      (tester) async {
    await _pump(tester, loggedIn: true);

    expect(find.text('Your SocialHub at a glance.'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);

    // Real values from the (overridden) summary.
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('7'), findsWidgets); // published count
    expect(find.text('Connected accounts'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Open dashboard'), findsOneWidget);
  });
}
