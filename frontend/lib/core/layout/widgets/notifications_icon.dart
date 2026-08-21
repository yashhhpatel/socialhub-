import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/notifications/data/api_notifications_repository.dart';
import '../../../features/notifications/domain/app_notification.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens/spacing_tokens.dart';

/// The top-bar notifications control (Phase 19). The bell shows a live unread
/// badge; opening it lists recent notifications, marks them read on open, and
/// deep-links to each item's page.
class NotificationsIcon extends ConsumerWidget {
  const NotificationsIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

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
      builder: (context, controller, child) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                // Opening the panel marks everything read; refresh both.
                controller.open();
                _markAllReadOnOpen(ref);
              }
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
          if (unread > 0)
            Positioned(
              right: 6,
              top: 6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _markAllReadOnOpen(WidgetRef ref) async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
    } catch (_) {
      // Best-effort — a failed mark-read shouldn't break opening the panel.
    }
    ref.invalidate(unreadNotificationsCountProvider);
  }
}

class _NotificationsPanel extends ConsumerWidget {
  const _NotificationsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listAsync = ref.watch(notificationsListProvider);

    return SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(SpacingTokens.md),
            child: Text('Notifications', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1),
          listAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const _EmptyState(),
            // A Column (not a ListView) because MenuAnchor measures its menu's
            // intrinsic size, which scrollables can't provide. The panel shows
            // the most recent items; older ones are still counted in the badge.
            data: (items) {
              if (items.isEmpty) return const _EmptyState();
              final shown = items.take(8).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _NotificationTile(
                      notification: shown[i],
                      onTap: () => _openItem(context, ref, shown[i]),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openItem(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    if (!n.isRead) {
      try {
        await ref.read(notificationsRepositoryProvider).markRead(n.id);
      } catch (_) {
        // best-effort
      }
      ref.invalidate(unreadNotificationsCountProvider);
    }
    if (context.mounted && n.linkPath != null && n.linkPath!.isNotEmpty) {
      context.go(n.linkPath!);
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
        'publish_succeeded' => Icons.check_circle_outline,
        'publish_failed' => Icons.error_outline,
        'invite_accepted' => Icons.person_add_alt_1,
        'approval_requested' => Icons.rate_review_outlined,
        'approval_approved' => Icons.thumb_up_outlined,
        'approval_rejected' => Icons.thumb_down_outlined,
        _ => Icons.notifications_outlined,
      };

  Color _iconColor() => switch (notification.type) {
        'publish_succeeded' || 'approval_approved' => AppColors.success,
        'publish_failed' || 'approval_rejected' => AppColors.error,
        _ => AppColors.accent,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead ? null : AppColors.surfaceRaised,
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 20, color: _iconColor()),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
    );
  }
}
