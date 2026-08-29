import 'package:flutter/material.dart';

import '../theme/tokens/spacing_tokens.dart';
import 'skeleton.dart';

/// A shimmer placeholder for a settings/detail form while it loads — a bordered
/// card with a few lines. Shared so form-style pages (Brand Kit, White Label,
/// AI Assistant, Organization, …) show a consistent, calm loading state instead
/// of a bare centered spinner.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key, this.lines = 3});

  /// How many field rows to suggest.
  final int lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 160, height: 18),
          const SizedBox(height: SpacingTokens.lg),
          for (var i = 0; i < lines; i++) ...[
            const Skeleton(width: 90, height: 12),
            const SizedBox(height: SpacingTokens.sm),
            Skeleton(
              width: double.infinity,
              height: 40,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: SpacingTokens.md),
          ],
        ],
      ),
    );
  }
}
