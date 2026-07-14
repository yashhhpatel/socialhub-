import 'package:flutter/material.dart';

import '../core/theme/tokens/spacing_tokens.dart';

/// Used by every stub feature screen (Content, Calendar, AI Assistant,
/// Analytics, Media Library, Team, Organizations, Settings) until each
/// gets built out for real in its own blueprint phase — see
/// core/layout/nav_destination_data.dart for which phase builds which.
///
/// Promoted straight to shared_widgets/ rather than started feature-local,
/// since it's needed by 8 features simultaneously from the moment it's
/// created — the usual "wait for duplication before promoting" rule
/// doesn't apply when the duplication is already obvious upfront.
class ComingSoonPlaceholder extends StatelessWidget {
  const ComingSoonPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: colorScheme.primary),
            ),
            const SizedBox(height: SpacingTokens.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.65),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.lg),
            Chip(
              avatar: const Icon(Icons.schedule, size: 16),
              label: const Text('Coming soon'),
              backgroundColor: colorScheme.primary.withOpacity(0.1),
            ),
          ],
        ),
      ),
    );
  }
}
