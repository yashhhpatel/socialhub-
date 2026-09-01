import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/features/auth/presentation/state/current_user_provider.dart';
import 'package:socialhub/features/marketplace/data/repositories/api_marketplace_repository.dart';
import 'package:socialhub/features/marketplace/presentation/screens/marketplace_screen.dart';
import 'package:socialhub/features/team/presentation/screens/team_screen.dart';
import 'package:socialhub/features/templates/domain/entities/template.dart';

/// A 401 like the API interceptor surfaces when signed out.
DioException _unauthorized() => DioException(
      requestOptions: RequestOptions(path: '/users/me'),
      response: Response(
        requestOptions: RequestOptions(path: '/users/me'),
        statusCode: 401,
      ),
    );

void main() {
  testWidgets(
    'Team page stays browsable when logged out — content shows, no sign-in wall',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Signed out: the profile fetch 401s.
            currentUserProvider.overrideWith((ref) async => throw _unauthorized()),
          ],
          // Mirror AppShell: a Scaffold hosting the screen inside a scroll
          // view (the signed-out demo roster is taller than one screen).
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TeamScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The page renders its real content...
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Invite teammate'), findsOneWidget);
      // ...populated with the demo roster.
      expect(find.text('you@yourbrand.com'), findsOneWidget);
      // ...and is NOT replaced by a blocking sign-in wall or an access denial.
      expect(find.text('Sign in to continue'), findsNothing);
      expect(find.text('Admins only'), findsNothing);
    },
  );

  testWidgets(
    'Marketplace Search stays clickable logged out and routes to login on tap',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/marketplace',
        routes: [
          GoRoute(
            // Mirror AppShell: a Scaffold hosting the screen inside a scroll view.
            path: '/marketplace',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: MarketplaceScreen()),
            ),
          ),
          GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN PAGE')),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Stub results so the screen never hits the network; the token
            // store defaults to null (logged out) in tests.
            marketplaceResultsProvider.overrideWith(
              (ref, MarketplaceQuery query) async => const <TemplateSummary>[],
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // The Search button is present and enabled.
      final search = find.widgetWithText(FilledButton, 'Search');
      expect(search, findsOneWidget);
      expect(tester.widget<FilledButton>(search).onPressed, isNotNull);

      await tester.tap(search);
      await tester.pumpAndSettle();

      // Tapping it while logged out sends the user to login.
      expect(find.text('LOGIN PAGE'), findsOneWidget);
    },
  );
}
