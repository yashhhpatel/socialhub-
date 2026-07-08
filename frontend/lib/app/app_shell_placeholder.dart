import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_mode_controller.dart';

/// Placeholder root screen for Milestone 0.2.
///
/// This exists only to prove the app shell, theming, and routing are wired
/// correctly end to end. It is intentionally NOT a "feature" — no
/// lib/features/ folder is created in this milestone. It will be replaced
/// once real routes (auth, dashboard, etc.) land in later milestones.
class AppShellPlaceholder extends ConsumerWidget {
  const AppShellPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SocialHub',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'App shell scaffold — Milestone 0.2',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Switch(
              value: isDark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
            ),
            Text(
              isDark ? 'Dark mode' : 'Light mode',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
