import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell_placeholder.dart';
import '../../features/ai_suite/presentation/screens/ai_assistant_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/brand_kit/presentation/screens/brand_kit_screen.dart';
import '../../features/team/presentation/screens/accept_invite_screen.dart';
import '../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../features/templates/presentation/screens/templates_screen.dart';
import '../../features/scheduler/presentation/screens/scheduler_screen.dart';
import '../../features/content/presentation/screens/content_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/media_library/presentation/screens/media_library_screen.dart';
import '../../features/organizations/presentation/screens/organizations_screen.dart';
import '../../features/social_accounts/presentation/screens/social_accounts_screen.dart';
import '../../features/team/presentation/screens/team_screen.dart';
import '../layout/app_shell.dart';
import '../network/auth_token_store.dart';
import 'go_router_refresh_notifier.dart';
import 'route_guards.dart';

/// Central route table. Per docs/architecture — Flutter Web Application
/// Architecture, §4 (Routing): features expose themselves as destinations,
/// the router owns URL structure — a feature never hardcodes its own path
/// elsewhere.
///
/// Authenticated destinations (dashboard + the 8 sidebar sections) are
/// nested inside a ShellRoute, so AppShell (sidebar/top bar) persists
/// across navigation between them instead of being rebuilt from scratch
/// on every route change. /, /login, /register stay outside the shell —
/// there's no sidebar to show before a session exists.
///
/// Route guard: GoRouter is constructed a single time here, with
/// `refreshListenable` telling it *when* to re-run `redirect`, and
/// `redirect` itself reading current auth state fresh via `ref.read`
/// each time it runs. Recreating the whole GoRouter instance on every
/// auth change (a common mistake when wiring Riverpod + GoRouter
/// together) would tear down navigator state — deliberately avoided.
///
/// /settings (Milestone 2.4): now renders SocialAccountsScreen — the
/// original features/settings/presentation/screens/settings_screen.dart
/// placeholder is left in place but unreferenced by any route, rather
/// than deleted. It becomes a real multi-section settings page (of which
/// Connected Accounts is the first section) once a second real settings
/// concern exists to sit alongside it — merging them prematurely, with
/// only one real section, would just be structure with nothing to
/// organize yet.
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
      // Public (Milestone 11.3): where an invite email link lands. Not in
      // navDestinations, so authRedirect leaves it reachable while logged out.
      GoRoute(
        path: '/accept-invite',
        name: 'accept-invite',
        builder: (context, state) =>
            AcceptInviteScreen(token: state.uri.queryParameters['token']),
      ),
      // Milestone 3.6. Deliberately OUTSIDE the ShellRoute: the editor is
      // a full-bleed workspace with its own toolbar, and keeping the
      // sidebar/top bar around it would leave the canvas fighting the app
      // chrome for horizontal space on exactly the screen that needs it
      // most. Its own back button returns to /content.
      //
      // Not covered by authRedirect's protectedRoutes (which derives from
      // navDestinations, and the editor is not a sidebar destination), so
      // it is guarded explicitly here.
      GoRoute(
        path: '/editor/:assetId',
        name: 'editor',
        redirect: (context, state) =>
            ref.read(authTokenStoreProvider) == null ? '/login' : null,
        builder: (context, state) =>
            EditorScreen(assetId: state.pathParameters['assetId']!),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentPath: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/content',
            name: 'content',
            builder: (context, state) => const ContentScreen(),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            builder: (context, state) => const SchedulerScreen(),
          ),
          GoRoute(
            path: '/ai-assistant',
            name: 'ai-assistant',
            builder: (context, state) => const AiAssistantScreen(),
          ),
          GoRoute(
            path: '/analytics',
            name: 'analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/media-library',
            name: 'media-library',
            builder: (context, state) => const MediaLibraryScreen(),
          ),
          GoRoute(
            path: '/team',
            name: 'team',
            builder: (context, state) => const TeamScreen(),
          ),
          GoRoute(
            path: '/organizations',
            name: 'organizations',
            builder: (context, state) => const OrganizationsScreen(),
          ),
          GoRoute(
            path: '/templates',
            name: 'templates',
            builder: (context, state) => const TemplatesScreen(),
          ),
          GoRoute(
            path: '/marketplace',
            name: 'marketplace',
            builder: (context, state) => const MarketplaceScreen(),
          ),
          GoRoute(
            path: '/brand-kit',
            name: 'brand-kit',
            builder: (context, state) => const BrandKitScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => SocialAccountsScreen(
              queryParams: state.uri.queryParameters,
            ),
          ),
        ],
      ),
    ],
  );
});
