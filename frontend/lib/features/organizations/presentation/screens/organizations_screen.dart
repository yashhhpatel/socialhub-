import 'package:flutter/material.dart';

import '../../../../shared_widgets/coming_soon_placeholder.dart';

/// Org-level settings/white-labeling land across Phase 11 and Phase 15 —
/// see docs/blueprint. Distinct from the backend's `organizations` module
/// (already built, Milestone 1.2) — this is the frontend UI for managing
/// what that module exposes.
class OrganizationsScreen extends StatelessWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      icon: Icons.apartment_outlined,
      title: 'Organizations',
      description:
          'Manage your organization\'s plan, branding, and connected '
          'workspaces.',
    );
  }
}
