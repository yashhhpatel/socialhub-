import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell_placeholder.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../network/auth_token_store.dart';
import 'go_router_refresh_notifier.dart';
import 'route_guards.dart';

/// Central route table. Per docs/architecture — Flutter Web Application
/// Architecture, §4 (Routing): features expose themselves as destinations,
/// the router owns URL structure — a feature never hardcodes its own path
/// elsewhere.
///
/// Route guard added ahead of schedule (see route_guards.dart's doc
/// comment for why) — built once, not recreated on every auth change:
/// GoRouter is constructed a single time here, with `refreshListenable`
/// telling it *when* to re-run `redirect`, and `redirect` itself reading
/// current auth state fresh via `ref.read` each time it runs. Recreating
/// the whole GoRouter instance on every auth change (a common mistake
/// when wiring Riverpod + GoRouter together) would tear down navigator
/// state — deliberately avoided here.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final isAuthenticated = ref.read(authTokenStoreProvider) != null;
      return authRedirect(
        matchedLocation: state.matchedLocation,
        isAuthenticated: isAuthenticated,
      );
    },
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
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
