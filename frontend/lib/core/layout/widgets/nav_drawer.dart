import 'package:flutter/material.dart';

import '../../theme/tokens/color_tokens.dart';
import '../../theme/tokens/spacing_tokens.dart';
import '../nav_menu_data.dart';

/// Mobile/tablet navigation drawer. Renders the SAME grouped hierarchy as
/// the desktop top nav: direct links plus each category's children under a
/// section header, so nothing is reachable on desktop but hidden here.
class NavDrawer extends StatelessWidget {
  const NavDrawer({
    super.key,
    required this.currentPath,
    required this.onDestinationSelected,
  });

  final String currentPath;
  final ValueChanged<String> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.md),
              child: Row(
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
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.sm),
                  Text('SocialHub', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
                children: [
                  for (final category in navMenu)
                    if (!category.isDropdown)
                      _DrawerLink(
                        icon: category.icon,
                        label: category.label,
                        selected: currentPath == category.path,
                        onTap: () => _select(context, category.path!),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SpacingTokens.md,
                          SpacingTokens.md,
                          SpacingTokens.md,
                          SpacingTokens.xs,
                        ),
                        child: Text(
                          category.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      for (final link in category.children)
                        _DrawerLink(
                          icon: link.icon,
                          label: link.label,
                          selected: currentPath == link.path,
                          onTap: () => _select(context, link.path),
                        ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, String path) {
    Navigator.of(context).pop(); // close the drawer first
    onDestinationSelected(path);
  }
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.sm,
        vertical: 2,
      ),
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
              horizontal: SpacingTokens.sm,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
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
