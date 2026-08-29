import 'package:flutter/material.dart';

/// Grouped top-navigation model (Buffer-style categories → dropdowns),
/// built around SocialHub's OWN existing pages — no invented routes.
///
/// This is purely the navbar's presentation structure. The flat list that
/// the route guard derives protected routes from still lives in
/// nav_destination_data.dart; every path here corresponds to a real route
/// in app_router.dart.
///
/// Hierarchy (our own, not copied from any reference):
///   Dashboard              — overview (direct link)
///   Create ▾               — everything for making a post
///     Content, Templates, Media Library, Brand Kit, AI Assistant, Marketplace
///   Calendar               — scheduling (direct link)
///   Analytics              — insights (direct link)
///   Workspace ▾            — org & account administration
///     Team, Organizations, White Label, Settings

/// A single navigable page inside a dropdown: icon + name + short blurb.
class NavLink {
  const NavLink({
    required this.path,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String path;
  final String label;
  final String description;
  final IconData icon;
}

/// A top-level navbar entry. Either a direct link (`path` set, `children`
/// empty) or a dropdown category (`children` non-empty).
class NavCategory {
  const NavCategory({
    required this.label,
    required this.icon,
    this.path,
    this.children = const [],
    this.columns = 1,
  });

  final String label;
  final IconData icon;

  /// Set for a direct top-level link (e.g. Dashboard). Null for a dropdown.
  final String? path;

  /// The pages shown in the dropdown. Empty for a direct link.
  final List<NavLink> children;

  /// How many columns the dropdown lays its children out in.
  final int columns;

  bool get isDropdown => children.isNotEmpty;

  /// True when [currentPath] is this entry (link) or one of its children.
  bool isActive(String currentPath) =>
      path == currentPath || children.any((c) => c.path == currentPath);
}

const List<NavCategory> navMenu = [
  NavCategory(
    label: 'Home',
    icon: Icons.home_outlined,
    path: '/',
  ),
  NavCategory(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    path: '/dashboard',
  ),
  NavCategory(
    label: 'Create',
    icon: Icons.add_circle_outline,
    columns: 2,
    children: [
      NavLink(
        path: '/content',
        label: 'Content',
        description: 'Your designs and drafts',
        icon: Icons.grid_view_outlined,
      ),
      NavLink(
        path: '/templates',
        label: 'Templates',
        description: 'Reusable design starting points',
        icon: Icons.dashboard_customize_outlined,
      ),
      NavLink(
        path: '/media-library',
        label: 'Media Library',
        description: 'Upload and reuse images & video',
        icon: Icons.perm_media_outlined,
      ),
      NavLink(
        path: '/brand-kit',
        label: 'Brand Kit',
        description: 'Colors, fonts and logos',
        icon: Icons.palette_outlined,
      ),
      NavLink(
        path: '/ai-assistant',
        label: 'AI Assistant',
        description: 'Hashtags, viral score & timing',
        icon: Icons.auto_awesome_outlined,
      ),
      NavLink(
        path: '/marketplace',
        label: 'Marketplace',
        description: 'Discover community templates',
        icon: Icons.storefront_outlined,
      ),
    ],
  ),
  NavCategory(
    label: 'Calendar',
    icon: Icons.calendar_today_outlined,
    path: '/calendar',
  ),
  NavCategory(
    label: 'Analytics',
    icon: Icons.bar_chart_outlined,
    path: '/analytics',
  ),
  NavCategory(
    label: 'Workspace',
    icon: Icons.workspaces_outline,
    columns: 2,
    children: [
      NavLink(
        path: '/team',
        label: 'Team',
        description: 'Members and their roles',
        icon: Icons.people_outline,
      ),
      NavLink(
        path: '/organizations',
        label: 'Organizations',
        description: 'Your organization overview',
        icon: Icons.apartment_outlined,
      ),
      NavLink(
        path: '/white-label',
        label: 'White Label',
        description: 'Custom branding for your org',
        icon: Icons.format_paint_outlined,
      ),
      NavLink(
        path: '/billing',
        label: 'Billing',
        description: 'Plan, usage and invoices',
        icon: Icons.credit_card_outlined,
      ),
      NavLink(
        path: '/settings',
        label: 'Settings',
        description: 'Connected accounts & appearance',
        icon: Icons.settings_outlined,
      ),
    ],
  ),
];
