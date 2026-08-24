import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';

/// One entry in the admin sidebar.
class AdminNavItem {
  const AdminNavItem(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}

/// Sections of the admin panel. Items are added as their milestones land.
const adminNavItems = <AdminNavItem>[
  AdminNavItem('Overview', Icons.dashboard_outlined, '/admin'),
];

/// Chrome for the platform-admin panel (Phase 21): its own header + sidebar,
/// separate from the tenant AppShell. Enforces the admin gate on the client
/// (the server enforces it independently via PlatformAdminGuard): a non-admin
/// or logged-out visitor never sees admin content.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.selectedPath, required this.child});

  final String selectedPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authTokenStoreProvider) != null;
    if (!loggedIn) {
      return _AdminGateMessage(
        title: 'Admin sign-in required',
        message: 'Log in with a platform-admin account to continue.',
        actionLabel: 'Log in',
        onAction: () => context.go('/login?from=/admin'),
      );
    }

    final me = ref.watch(adminMeProvider);
    return me.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _AdminGateMessage(
        title: 'Not authorized',
        message: isUnauthorized(error)
            ? 'Log in with a platform-admin account to continue.'
            : 'This area is restricted to platform admins.',
        actionLabel: 'Back to app',
        onAction: () => context.go('/'),
      ),
      data: (email) => _AdminScaffold(
        adminEmail: email,
        selectedPath: selectedPath,
        child: child,
      ),
    );
  }
}

class _AdminScaffold extends StatelessWidget {
  const _AdminScaffold({
    required this.adminEmail,
    required this.selectedPath,
    required this.child,
  });

  final String adminEmail;
  final String selectedPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.lg),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.accent, size: 22),
                  const SizedBox(width: SpacingTokens.sm),
                  Text('SocialHub Admin', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    adminEmail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.md),
                  TextButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to app'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    _Sidebar(selectedPath: selectedPath),
                  Expanded(
                    child: SingleChildScrollView(child: child),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedPath});

  final String selectedPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: SpacingTokens.md),
        children: [
          for (final item in adminNavItems)
            _NavTile(
              item: item,
              selected: selectedPath == item.path,
              onTap: () => context.go(item.path),
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.sm,
        vertical: 2,
      ),
      child: Material(
        color: selected ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? theme.colorScheme.onSurface : AppColors.textMuted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminGateMessage extends StatelessWidget {
  const _AdminGateMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: SpacingTokens.md),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: SpacingTokens.xs),
            Text(message, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: SpacingTokens.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
