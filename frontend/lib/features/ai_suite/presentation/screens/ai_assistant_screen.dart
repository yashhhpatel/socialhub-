import 'package:flutter/material.dart';

import '../../../../shared_widgets/coming_soon_placeholder.dart';

/// Real AI features land in Phase 5 (captions) and Phase 12 (hashtags,
/// tone conversion, viral score, best-time) — see docs/blueprint. Folder
/// named ai_suite (not ai_assistant) to stay consistent with the
/// blueprint's naming; only the user-facing label says "AI Assistant".
class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      icon: Icons.auto_awesome_outlined,
      title: 'AI Assistant',
      description:
          'Generate captions, hashtags, and content ideas — with tone '
          'conversion and viral-score predictions.',
    );
  }
}
