import 'package:flutter/material.dart';

import '../../../../shared_widgets/coming_soon_placeholder.dart';

/// Real analytics dashboard lands in Phase 10 — see docs/blueprint.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      icon: Icons.bar_chart_outlined,
      title: 'Analytics',
      description:
          'Unified performance metrics across every connected platform, '
          'with cross-platform comparison.',
    );
  }
}
