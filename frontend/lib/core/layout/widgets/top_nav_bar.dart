import 'package:flutter/material.dart';

import '../../theme/tokens/color_tokens.dart';
import '../../theme/tokens/spacing_tokens.dart';
import '../nav_menu_data.dart';
import 'notifications_icon.dart';
import 'user_profile_menu.dart';

/// Horizontal top navigation with grouped categories and Buffer-style
/// dropdown mega-menus. Compact by design — only a handful of top-level
/// entries, so nothing ever scrolls horizontally.
///
/// On mobile the categories collapse to a menu button that opens the
/// [NavDrawer]; the brand + notifications + profile stay in the bar.
class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  const TopNavBar({
    super.key,
    required this.currentPath,
    required this.userEmail,
    required this.userRole,
    required this.isAuthenticated,
    required this.onLogin,
    required this.onLogout,
    required this.onOpenSettings,
    required this.onDestinationSelected,
    required this.isMobile,
  });

  final String currentPath;
  final String userEmail;
  final String userRole;
  final bool isAuthenticated;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onDestinationSelected;
  final bool isMobile;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
            child: isMobile ? _buildMobile(context) : _buildDesktop(context),
          ),
        ),
      ),
    );
  }

  /// Three balanced sections via equal-flex left/right, so the center
  /// navigation stays visually centered in the header at any desktop width.
  /// Left and right hold their content against the outer edges; the center
  /// keeps its natural width between them. No fixed/absolute positioning.
  Widget _buildDesktop(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Align(alignment: Alignment.centerLeft, child: _Brand()),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final category in navMenu)
              _CategoryEntry(
                category: category,
                currentPath: currentPath,
                onSelect: onDestinationSelected,
              ),
          ],
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _rightControls(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const SizedBox(width: SpacingTokens.xs),
        const _Brand(),
        const Spacer(),
        _rightControls(context),
      ],
    );
  }

  /// Right section: notifications, then either the Login control (logged
  /// out) or the existing user/profile menu (logged in).
  Widget _rightControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NotificationsIcon(),
        const SizedBox(width: SpacingTokens.sm),
        if (isAuthenticated)
          UserProfileMenu(
            email: userEmail,
            role: userRole,
            onLogout: onLogout,
            onOpenSettings: onOpenSettings,
          )
        else
          FilledButton(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.md,
                vertical: 10,
              ),
            ),
            child: const Text('Log in'),
          ),
      ],
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

/// A top-level bar entry: either a direct link or a dropdown trigger.
class _CategoryEntry extends StatelessWidget {
  const _CategoryEntry({
    required this.category,
    required this.currentPath,
    required this.onSelect,
  });

  final NavCategory category;
  final String currentPath;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = category.isActive(currentPath);

    if (!category.isDropdown) {
      return _NavTrigger(
        label: category.label,
        active: active,
        showChevron: false,
        onTap: () => onSelect(category.path!),
      );
    }
    return _CategoryDropdown(
      category: category,
      active: active,
      currentPath: currentPath,
      onSelect: onSelect,
    );
  }
}

/// Dropdown trigger + its mega-menu panel. Stateful so it can own a
/// [MenuController] and close the menu itself after a child is chosen.
class _CategoryDropdown extends StatefulWidget {
  const _CategoryDropdown({
    required this.category,
    required this.active,
    required this.currentPath,
    required this.onSelect,
  });

  final NavCategory category;
  final bool active;
  final String currentPath;
  final ValueChanged<String> onSelect;

  @override
  State<_CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<_CategoryDropdown> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor),
          ),
        ),
      ),
      menuChildren: [
        _MegaPanel(
          category: widget.category,
          currentPath: widget.currentPath,
          onSelect: (path) {
            _controller.close();
            widget.onSelect(path);
          },
        ),
      ],
      builder: (context, controller, child) => _NavTrigger(
        label: widget.category.label,
        active: widget.active,
        showChevron: true,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _NavTrigger extends StatelessWidget {
  const _NavTrigger({
    required this.label,
    required this.active,
    required this.showChevron,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
      child: Material(
        color: active
            ? colorScheme.primary.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.sm,
              vertical: 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dropdown body: a padded grid of [_MegaItem]s, laid out in the
/// category's column count.
class _MegaPanel extends StatelessWidget {
  const _MegaPanel({
    required this.category,
    required this.currentPath,
    required this.onSelect,
  });

  final NavCategory category;
  final String currentPath;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const itemWidth = 272.0;
    final width = category.columns * itemWidth + SpacingTokens.md;

    return Container(
      width: width,
      padding: const EdgeInsets.all(SpacingTokens.sm),
      child: Wrap(
        children: [
          for (final link in category.children)
            SizedBox(
              width: itemWidth,
              child: _MegaItem(
                link: link,
                selected: currentPath == link.path,
                onTap: () => onSelect(link.path),
              ),
            ),
        ],
      ),
    );
  }
}

class _MegaItem extends StatelessWidget {
  const _MegaItem({
    required this.link,
    required this.selected,
    required this.onTap,
  });

  final NavLink link;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? colorScheme.primary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(link.icon, size: 20, color: colorScheme.primary),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        link.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
