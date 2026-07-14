import 'package:flutter/material.dart';

/// Placeholder only — no real notification feed exists yet. The badge
/// count is static, illustrating where real unread-count state will
/// plug in once a notifications feature exists; deliberately not wired
/// to any provider yet rather than fabricating fake "live" behavior.
class NotificationsIcon extends StatelessWidget {
  const NotificationsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications are coming soon.')),
        );
      },
      icon: Badge(
        label: const Text('3'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
