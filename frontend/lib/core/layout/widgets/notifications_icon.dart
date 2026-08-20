import 'package:flutter/material.dart';

import '../../theme/tokens/spacing_tokens.dart';

/// The top-bar notifications control. Opens a small popover panel anchored
/// under the bell.
///
/// There is no notifications backend yet, so the panel shows an honest
/// "all caught up" empty state rather than a fake unread badge or a "coming
/// soon" toast. When a real feed lands, [_NotificationsPanel] is the single
/// place that renders items and the bell can take a live unread count.
class NotificationsIcon extends StatelessWidget {
  const NotificationsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-300, 8),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
      ),
      menuChildren: const [_NotificationsPanel()],
      builder: (context, controller, child) => IconButton(
        tooltip: 'Notifications',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(SpacingTokens.md),
            child: Text('Notifications', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.lg,
              vertical: SpacingTokens.xl,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  "You're all caught up",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  'New activity on your posts, schedule and team will appear here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
