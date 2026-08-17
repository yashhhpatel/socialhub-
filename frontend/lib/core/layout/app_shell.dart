import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/state/auth_controller.dart';
import '../theme/app_background.dart';
import 'widgets/top_nav_bar.dart';

/// The persistent shell every authenticated route renders inside (via
/// app_router.dart's ShellRoute): a horizontal top navigation bar above the
/// routed content. (Previously a left sidebar — the nav moved to the top;
/// destinations and routing are unchanged.)
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
/// TopNavBar) all stay dependency-free and presentational precisely so
/// this exception is contained to one file, not spread throughout core/.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final email = session?.email ?? '';
    final role = session?.role ?? '';

    void handleLogout() => ref.read(authControllerProvider.notifier).logout();
    void handleDestinationSelected(String path) => context.go(path);
    void handleOpenSettings() => context.go('/settings');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TopNavBar(
        currentPath: currentPath,
        userEmail: email,
        userRole: role,
        onLogout: handleLogout,
        onOpenSettings: handleOpenSettings,
        onDestinationSelected: handleDestinationSelected,
      ),
      body: AppBackground(child: child),
    );
  }
}
