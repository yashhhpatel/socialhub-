import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/state/auth_controller.dart';
import '../theme/breakpoints.dart';
import 'nav_destination_data.dart';
import 'widgets/nav_sidebar.dart';
import 'widgets/nav_top_bar.dart';

/// The persistent shell every authenticated route renders inside (via
/// app_router.dart's ShellRoute) — sidebar/top bar on desktop+tablet,
/// a Drawer on mobile.
///
/// DELIBERATE EXCEPTION to the architecture doc's "core/ never depends
/// on a feature" rule: this file imports `authControllerProvider` from
/// features/auth, for the user's email/role display and the logout
/// action. This isn't an oversight — it mirrors the precedent already
/// set by core/router/app_router.dart, which has imported LoginScreen/
/// RegisterScreen/DashboardScreen directly from features/ since
/// Milestone 1.3. Something has to compose features into the app, and
/// the shell (like the router) is exactly that composition root — the
/// individual widgets it renders (UserProfileMenu, NavSidebar,
/// NavTopBar) all stay dependency-free and presentational precisely so
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

    final title = navDestinations
        .firstWhere(
          (d) => d.path == currentPath,
          orElse: () => navDestinations.first,
        )
        .label;

    if (Breakpoints.isMobile(context)) {
      return Scaffold(
        appBar: NavTopBar(
          title: title,
          userEmail: email,
          userRole: role,
          onLogout: handleLogout,
          onOpenSettings: handleOpenSettings,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: Drawer(
          child: SafeArea(
            child: NavSidebar(
              currentPath: currentPath,
              expanded: true,
              onDestinationSelected: (path) {
                Navigator.of(context).pop(); // close the drawer first
                handleDestinationSelected(path);
              },
            ),
          ),
        ),
        body: child,
      );
    }

    final sidebarExpanded = Breakpoints.isDesktop(context);

    return Scaffold(
      body: Row(
        children: [
          NavSidebar(
            currentPath: currentPath,
            expanded: sidebarExpanded,
            onDestinationSelected: handleDestinationSelected,
          ),
          Expanded(
            child: Scaffold(
              appBar: NavTopBar(
                title: title,
                userEmail: email,
                userRole: role,
                onLogout: handleLogout,
                onOpenSettings: handleOpenSettings,
              ),
              body: child,
            ),
          ),
        ],
      ),
    );
  }
}
