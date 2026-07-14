import 'package:flutter/material.dart';

import '../../../../shared_widgets/coming_soon_placeholder.dart';

/// Real team management (invites, roles) lands in Phase 11 — see
/// docs/blueprint.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      icon: Icons.people_outline,
      title: 'Team',
      description:
          'Invite teammates and manage roles — owner, admin, editor, and '
          'viewer.',
    );
  }
}
