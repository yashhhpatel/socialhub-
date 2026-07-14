import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';

/// One reusable card, parameterized, rather than 5 near-duplicate widgets
/// — per requirement 8 (reusable widgets). Feature-local for now (only
/// the dashboard uses it); promote to shared_widgets/ if a second feature
/// later needs the same shape, per the architecture doc's reuse rule.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.65),
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: SpacingTokens.sm),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
