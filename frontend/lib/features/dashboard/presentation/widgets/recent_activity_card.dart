import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../domain/entities/dashboard_summary.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({super.key, required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          Text('Recent Activity', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: SpacingTokens.md),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SpacingTokens.lg),
              child: Text(
                'No recent activity yet.',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _ActivityRow(item: items[i]),
              if (i != items.length - 1) const Divider(height: SpacingTokens.lg),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  IconData get _icon {
    switch (item.icon) {
      case 'published':
        return Icons.check_circle_outline;
      case 'account':
        return Icons.link;
      case 'draft':
        return Icons.edit_outlined;
      case 'scheduled':
        return Icons.schedule;
      case 'ai':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: SpacingTokens.sm),
        Expanded(
          child: Text(item.description, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: SpacingTokens.sm),
        Text(
          item.timeAgo,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
