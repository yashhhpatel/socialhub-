import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell_placeholder.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';

/// Central route table. Per docs/architecture — Flutter Web Application
/// Architecture, §4 (Routing): features expose themselves as destinations,
/// the router owns URL structure — a feature never hardcodes its own path
/// elsewhere.
///
/// Milestone 1.3 adds /login and /register. Route guards (redirecting an
/// unauthenticated user away from protected routes) are deliberately NOT
/// added yet — that depends on a persisted, real session, which lands in
/// Milestone 1.4 (token storage/refresh) and beyond. Until then, '/'
/// remains reachable directly; it links to /login for manual testing.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'root',
        builder: (context, state) => const AppShellPlaceholder(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );
});
