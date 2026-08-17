import 'package:flutter/material.dart';

import '../../theme/tokens/color_tokens.dart';
import '../../theme/tokens/spacing_tokens.dart';
import '../nav_destination_data.dart';
import 'notifications_icon.dart';
import 'user_profile_menu.dart';

/// Horizontal top navigation — replaces the old left sidebar. Holds the
/// brand, every nav destination as a horizontal item (scrollable when they
/// don't all fit), and the notifications + profile actions on the right.
///
/// Same destinations, same routing callbacks as before; only the layout
/// moved from a vertical rail to a top bar.
class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  const TopNavBar({
    super.key,
    required this.currentPath,
    required this.userEmail,
    required this.userRole,
    required this.onLogout,
    required this.onOpenSettings,
    required this.onDestinationSelected,
  });

  final String currentPath;
  final String userEmail;
  final String userRole;
  final VoidCallback onLogout;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onDestinationSelected;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: SpacingTokens.md),
              const _Brand(),
              const SizedBox(width: SpacingTokens.md),
              Container(width: 1, height: 28, color: theme.dividerColor),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.sm,
                  ),
                  child: Row(
                    children: [
                      for (final destination in navDestinations)
                        _NavItem(
                          destination: destination,
                          selected: currentPath == destination.path,
                          onTap: () => onDestinationSelected(destination.path),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              const NotificationsIcon(),
              const SizedBox(width: SpacingTokens.xs),
              UserProfileMenu(
                email: userEmail,
                role: userRole,
                onLogout: onLogout,
                onOpenSettings: onOpenSettings,
              ),
              const SizedBox(width: SpacingTokens.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ColorTokens.brandPrimary, ColorTokens.blobPink],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: ColorTokens.brandPrimary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.hub_outlined, size: 18, color: Colors.white),
        ),
        const SizedBox(width: SpacingTokens.sm),
        Text(
          'SocialHub',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestinationData destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
      child: Material(
        color: selected
            ? colorScheme.primary.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.sm + 2,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 18,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
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
