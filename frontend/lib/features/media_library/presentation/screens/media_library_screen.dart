import 'package:flutter/material.dart';

import '../../../../shared_widgets/coming_soon_placeholder.dart';

/// Real media management arrives alongside Phase 9's brand kit/template
/// work — see docs/blueprint.
class MediaLibraryScreen extends StatelessWidget {
  const MediaLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      icon: Icons.perm_media_outlined,
      title: 'Media Library',
      description:
          'All your uploaded images and videos, organized and ready to '
          'drop into any design.',
    );
  }
}
