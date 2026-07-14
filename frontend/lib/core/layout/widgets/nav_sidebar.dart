import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens/spacing_tokens.dart';
import '../nav_destination_data.dart';

/// The persistent left nav for desktop/tablet. Mobile uses a Drawer
/// instead (see app_shell.dart) — 9 destinations don't fit a bottom nav
/// bar (which the architecture doc's general guidance assumes a small
/// item count for), so mobile gets the standard Material pattern for
/// many-item navigation: a hamburger-triggered drawer reusing this same
/// destination list.
class NavSidebar extends StatelessWidget {
  const NavSidebar({
    super.key,
    required this.currentPath,
    required this.expanded,
    required this.onDestinationSelected,
  });

  final String currentPath;
  final bool expanded;
  final ValueChanged<String> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: expanded ? 240 : 76,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Brand(expanded: expanded),
          const Divider(height: 1),
          const SizedBox(height: SpacingTokens.sm),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.sm),
              children: [
                for (final destination in navDestinations)
                  _SidebarItem(
                    destination: destination,
                    selected: currentPath == destination.path,
                    expanded: expanded,
                    onTap: () => onDestinationSelected(destination.path),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: Row(
        mainAxisAlignment:
            expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hub_outlined, size: 18, color: Colors.white),
          ),
          if (expanded) ...[
            const SizedBox(width: SpacingTokens.sm),
            Text(
              'SocialHub',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 18,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final NavDestinationData destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? colorScheme.primary.withOpacity(0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? SpacingTokens.sm : 0,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                ),
                if (expanded) ...[
                  const SizedBox(width: SpacingTokens.sm),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: TextStyle(
                        color:
                            selected ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Icon-only (tablet) mode still needs a way to know what each icon
    // means — a tooltip is the minimal, correct affordance rather than
    // guessing the user will remember 9 icons.
    return expanded ? item : Tooltip(message: destination.label, child: item);
  }
}
