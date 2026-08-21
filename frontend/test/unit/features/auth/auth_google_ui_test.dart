import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/features/auth/presentation/screens/login_screen.dart';
import 'package:socialhub/features/auth/presentation/screens/register_screen.dart';

Widget _host(String routePath, String initialLocation, Widget screen) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: routePath, builder: (_, __) => screen),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('login shows Google button + email divider', (tester) async {
    await tester.pumpWidget(_host('/login', '/login', const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or continue with email'), findsOneWidget);
    // Email/password login is preserved.
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('login surfaces a Google error from ?error=google',
      (tester) async {
    await tester.pumpWidget(_host('/login', '/login?error=google', const LoginScreen()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("Google sign-in didn't complete"),
      findsOneWidget,
    );
  });

  testWidgets('register shows Google button and NO organization field',
      (tester) async {
    await tester.pumpWidget(_host('/register', '/register', const RegisterScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or continue with email'), findsOneWidget);
    // Org name is gone; email + password + sign up remain.
    expect(find.text('Organization name'), findsNothing);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
