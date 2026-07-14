import 'package:flutter/material.dart';

import '../../../../shared_widgets/coming_soon_placeholder.dart';

/// Real content lands in Phase 3 (editor) and Phase 9 (templates, brand
/// kit) — see docs/blueprint. This stub exists so the sidebar item is
/// navigable now rather than dead.
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      icon: Icons.grid_view_outlined,
      title: 'Content',
      description:
          'Your design editor and content library will live here — create '
          'once, then publish everywhere.',
    );
  }
}
