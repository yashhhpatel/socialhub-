import 'package:flutter/material.dart';

import '../../../../shared_widgets/coming_soon_placeholder.dart';

/// Real settings (profile, brand kit, white-labeling) accumulate across
/// several phases — see docs/blueprint. Reachable both from the sidebar
/// and from the user profile menu's "Settings" item (see AppShell).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      icon: Icons.settings_outlined,
      title: 'Settings',
      description:
          'Account, brand kit, and organization preferences will live '
          'here.',
    );
  }
}
