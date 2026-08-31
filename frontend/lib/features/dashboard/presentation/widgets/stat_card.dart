import 'package:flutter/material.dart';

import '../../../../core/motion/tap_scale.dart';
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

    return TapScale(
      hoverElevation: true,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        decoration: BoxDecoration(
          // A soft accent wash (top-left) fading into the surface, plus an
          // accent-tinted border, gives each card a distinct pop of colour
          // without turning the calm dark theme flashy.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withOpacity(0.10), colorScheme.surface],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.22)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: accent),
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: SpacingTokens.sm),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}
