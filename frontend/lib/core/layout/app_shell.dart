import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/state/auth_controller.dart';
import '../../features/auth/presentation/widgets/email_verification_banner.dart';
import '../theme/app_background.dart';
import '../theme/breakpoints.dart';
import 'widgets/app_footer.dart';
import 'widgets/nav_drawer.dart';
import 'widgets/top_nav_bar.dart';

/// The persistent shell every authenticated route renders inside (via
/// app_router.dart's ShellRoute): a grouped horizontal top navigation bar
/// above the routed content, collapsing to a menu drawer on mobile.
/// (Previously a left sidebar — the nav moved to the top; destinations and
/// routing are unchanged.)
///
/// DELIBERATE EXCEPTION to the architecture doc's "core/ never depends
/// on a feature" rule: this file imports `authControllerProvider` from
/// features/auth, for the user's email/role display and the logout
/// action. This isn't an oversight — it mirrors the precedent already
/// set by core/router/app_router.dart, which has imported LoginScreen/
/// RegisterScreen/DashboardScreen directly from features/ since
/// Milestone 1.3. Something has to compose features into the app, and
/// the shell (like the router) is exactly that composition root — the
/// individual widgets it renders (UserProfileMenu, NotificationsIcon,
/// TopNavBar, NavDrawer) all stay dependency-free and presentational
/// precisely so this exception is contained to one file.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final email = session?.email ?? '';
    final role = session?.role ?? '';
    final isAuthenticated = session != null;
    final isMobile = Breakpoints.isMobile(context);

    // The public home lives at `/` but shows the dashboard overview, so
    // highlight the Dashboard nav item there too.
    final highlightPath = currentPath == '/' ? '/dashboard' : currentPath;

    void handleLogout() => ref.read(authControllerProvider.notifier).logout();
    void handleDestinationSelected(String path) => context.go(path);
    void handleOpenSettings() => context.go('/settings');
    void handleLogin() => context.go('/login');
    void handleRegister() => context.go('/register');

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: isMobile
          ? NavDrawer(
              currentPath: highlightPath,
              onDestinationSelected: handleDestinationSelected,
            )
          : null,
      appBar: TopNavBar(
        currentPath: highlightPath,
        userEmail: email,
        userRole: role,
        isAuthenticated: isAuthenticated,
        onLogin: handleLogin,
        onRegister: handleRegister,
        onLogout: handleLogout,
        onOpenSettings: handleOpenSettings,
        onDestinationSelected: handleDestinationSelected,
        isMobile: isMobile,
      ),
      // One scroll owns the whole page: the routed content (given at least a
      // viewport of height so short pages still fill the screen) followed by
      // the global footer. AppBackground stays fixed behind the scroll.
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EmailVerificationBanner(),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: child,
                ),
                const AppFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
