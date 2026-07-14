import 'package:flutter/material.dart';

import '../../../../shared_widgets/coming_soon_placeholder.dart';

/// Real scheduling calendar lands in Phase 7 — see docs/blueprint.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      icon: Icons.calendar_today_outlined,
      title: 'Calendar',
      description:
          'Schedule posts across every connected platform and see your '
          'whole content calendar at a glance.',
    );
  }
}
