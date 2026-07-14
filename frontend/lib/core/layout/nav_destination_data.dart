import 'package:flutter/material.dart';

/// One nav destination: what the sidebar/drawer render, and what the
/// route guard protects. Adding a 10th sidebar item later is a one-line
/// addition here, not a change in three separate places.
class NavDestinationData {
  const NavDestinationData({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The 9 sections requested for this dashboard shell. Only Dashboard has
/// real content right now (see features/dashboard/) — the other 8 render
/// a shared "coming soon" placeholder (see shared_widgets/) until their
/// own phases in the blueprint build them out for real:
///   Content         -> Phase 3 (editor) / Phase 9 (templates, brand kit)
///   Calendar        -> Phase 7 (scheduling)
///   AI Assistant    -> Phase 5 (captions) / Phase 12 (full AI suite)
///   Analytics       -> Phase 10
///   Media Library   -> Phase 9
///   Team            -> Phase 11
///   Organizations   -> Phase 11 / Phase 15 (white-labeling)
///   Settings        -> spans several phases
const List<NavDestinationData> navDestinations = [
  NavDestinationData(
    path: '/dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  NavDestinationData(
    path: '/content',
    label: 'Content',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view,
  ),
  NavDestinationData(
    path: '/calendar',
    label: 'Calendar',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
  ),
  NavDestinationData(
    path: '/ai-assistant',
    label: 'AI Assistant',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
  ),
  NavDestinationData(
    path: '/analytics',
    label: 'Analytics',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
  ),
  NavDestinationData(
    path: '/media-library',
    label: 'Media Library',
    icon: Icons.perm_media_outlined,
    selectedIcon: Icons.perm_media,
  ),
  NavDestinationData(
    path: '/team',
    label: 'Team',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  NavDestinationData(
    path: '/organizations',
    label: 'Organizations',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment,
  ),
  NavDestinationData(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];
