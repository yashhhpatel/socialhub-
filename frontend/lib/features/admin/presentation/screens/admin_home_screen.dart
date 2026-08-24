import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';

/// Admin panel landing (Phase 21.1). The cross-tenant Overview dashboard with
/// real KPIs lands in 21.2; for now this confirms admin access and orients the
/// operator.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Platform administration for SocialHub — manage tenants, users, '
            'social connections, billing, content, and system health across all '
            'organizations.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Text(
                    "You're signed in as a platform admin. Cross-tenant metrics "
                    'and management tools appear here as they roll out.',
                    style: theme.textTheme.bodyMedium,
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
