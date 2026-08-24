import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_org_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_organizations_screen.dart';
import '../../features/admin/presentation/screens/admin_overview_screen.dart';
import '../../features/admin/presentation/screens/admin_user_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../features/admin/presentation/widgets/admin_shell.dart';
import '../../features/ai_suite/presentation/screens/ai_assistant_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/google_callback_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/mfa_challenge_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/billing/presentation/screens/billing_screen.dart';
import '../../features/brand_kit/presentation/screens/brand_kit_screen.dart';
import '../../features/team/presentation/screens/accept_invite_screen.dart';
import '../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../features/templates/presentation/screens/templates_screen.dart';
import '../../features/scheduler/presentation/screens/scheduler_screen.dart';
import '../../features/content/presentation/screens/content_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/info/info_page_screen.dart';
import '../../features/media_library/presentation/screens/media_library_screen.dart';
import '../../features/organizations/presentation/screens/organizations_screen.dart';
import '../../features/settings/white_label_screen.dart';
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
/// Destinations are nested inside a ShellRoute, so AppShell (the top nav
/// bar) persists across navigation between them instead of being rebuilt
/// from scratch on every route change. `/` lives inside the shell too — it
/// is the public home (see its route below), so the header shows there even
/// when logged out, with a Login control. Only /login and /register stay
/// outside the shell — those are the standalone auth screens.
///
/// Route guard: GoRouter is constructed a single time here, with
/// `refreshListenable` telling it *when* to re-run `redirect`, and
/// `redirect` itself reading current auth state fresh via `ref.read`
/// each time it runs. Recreating the whole GoRouter instance on every
/// auth change (a common mistake when wiring Riverpod + GoRouter
/// together) would tear down navigator state — deliberately avoided.
///
/// /settings renders SocialAccountsScreen, which is now a real
/// multi-section settings page: Appearance (theme) + Connected accounts.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final isAuthenticated = ref.read(authTokenStoreProvider) != null;

      // Return-to-after-login: when an authenticated user lands on the auth
      // screens carrying a `?from=` (set when a protected action bounced them
      // here), send them back to where they were instead of the dashboard.
      if (isAuthenticated &&
          (state.matchedLocation == '/login' ||
              state.matchedLocation == '/register')) {
        final from = state.uri.queryParameters['from'];
        if (from != null &&
            from.isNotEmpty &&
            !from.startsWith('/login') &&
            !from.startsWith('/register')) {
          return from;
        }
      }

      return authRedirect(
        matchedLocation: state.matchedLocation,
        isAuthenticated: isAuthenticated,
      );
    },
    routes: [
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
      // Public account-lifecycle screens (Phase 17.1). Standalone (outside the
      // shell, like /login) and not in navDestinations, so they're reachable
      // whether or not the user is signed in — the reset/verify links arrive
      // by email and carry their own token.
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Landing point for the Google sign-in redirect. Standalone (outside the
      // shell, like /login) and not in navDestinations, so it's reachable while
      // logged out; it reads the single-use handoff ticket from the URL and
      // exchanges it for a session, then routes the user on.
      GoRoute(
        path: '/auth/google',
        name: 'auth-google',
        builder: (context, state) =>
            GoogleCallbackScreen(ticket: state.uri.queryParameters['ticket']),
      ),
      // Second step of an MFA login (Phase 17.3). Standalone auth screen; the
      // challenge token lives in AuthController state, so a direct visit with
      // no pending challenge bounces itself back to /login.
      GoRoute(
        path: '/mfa-challenge',
        name: 'mfa-challenge',
        builder: (context, state) => const MfaChallengeScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(token: state.uri.queryParameters['token']),
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
      // Platform admin panel (Phase 21). Standalone, OUTSIDE the tenant
      // AppShell — it has its own AdminShell (header + sidebar). Reachable only
      // by platform admins; AdminShell enforces the client gate and the backend
      // enforces it independently via PlatformAdminGuard. Not in navDestinations,
      // so authRedirect leaves it addressable (the shell handles logged-out).
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminShell(
          selectedPath: '/admin',
          child: AdminOverviewScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/organizations',
        name: 'admin-organizations',
        builder: (context, state) => const AdminShell(
          selectedPath: '/admin/organizations',
          child: AdminOrganizationsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/organizations/:id',
        name: 'admin-organization-detail',
        builder: (context, state) => AdminShell(
          selectedPath: '/admin/organizations',
          child: AdminOrgDetailScreen(orgId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/admin/users',
        name: 'admin-users',
        builder: (context, state) => const AdminShell(
          selectedPath: '/admin/users',
          child: AdminUsersScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/users/:id',
        name: 'admin-user-detail',
        builder: (context, state) => AdminShell(
          selectedPath: '/admin/users',
          child: AdminUserDetailScreen(userId: state.pathParameters['id']!),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentPath: state.matchedLocation,
          child: child,
        ),
        routes: [
          // Root is the public home: it renders the main SocialHub page
          // (the dashboard overview) inside the shell for everyone, so an
          // unauthenticated visitor lands here instead of being bounced to
          // /login. Signed-in users are sent on to /dashboard so the rest of
          // the authenticated experience is unchanged. `/` itself is not in
          // navDestinations, so authRedirect leaves it publicly reachable.
          GoRoute(
            path: '/',
            name: 'root',
            redirect: (context, state) =>
                ref.read(authTokenStoreProvider) != null ? '/dashboard' : null,
            builder: (context, state) => const DashboardScreen(),
          ),
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
            path: '/white-label',
            name: 'white-label',
            builder: (context, state) => const WhiteLabelScreen(),
          ),
          GoRoute(
            path: '/billing',
            name: 'billing',
            builder: (context, state) => const BillingScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => SocialAccountsScreen(
              queryParams: state.uri.queryParameters,
            ),
          ),
          // Static informational + legal pages linked from the global footer.
          // Public (not in navDestinations, no auth needed) and inside the
          // shell so they carry the same header and footer as every page.
          for (final slug in const [
            'about',
            'contact',
            'security',
            'help',
            'privacy',
            'terms',
          ])
            GoRoute(
              path: '/$slug',
              name: slug,
              builder: (context, state) => InfoPageScreen(slug: slug),
            ),
        ],
      ),
    ],
  );
});
