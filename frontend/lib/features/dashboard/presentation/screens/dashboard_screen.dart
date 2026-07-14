import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/breakpoints.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/dashboard_mock_data.dart';
import '../widgets/recent_activity_card.dart';
import '../widgets/stat_card.dart';

/// The real dashboard content — rendered inside AppShell's content area,
/// not a standalone Scaffold (AppShell owns the sidebar/top bar now).
///
/// Data comes from dashboardSummaryProvider, currently backed by mock
/// data (see features/dashboard/data/dashboard_mock_data.dart) — this
/// screen has no idea that's true, since it only depends on the
/// DashboardSummary shape, not how it's produced.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final columns = Breakpoints.isDesktop(context)
        ? 3
        : Breakpoints.isTablet(context)
            ? 2
            : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Here\'s what\'s happening across your connected platforms.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: SpacingTokens.md,
            mainAxisSpacing: SpacingTokens.md,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                icon: Icons.schedule,
                label: 'Scheduled Posts',
                value: '${summary.scheduledPosts}',
              ),
              StatCard(
                icon: Icons.check_circle_outline,
                label: 'Published Posts',
                value: '${summary.publishedPosts}',
              ),
              StatCard(
                icon: Icons.edit_outlined,
                label: 'Drafts',
                value: '${summary.drafts}',
              ),
              StatCard(
                icon: Icons.link,
                label: 'Connected Accounts',
                value: '${summary.connectedAccounts}',
                subtitle: 'Manage in Settings',
              ),
              StatCard(
                icon: Icons.auto_awesome_outlined,
                label: 'AI Credits',
                value: '${summary.aiCreditsUsed} / ${summary.aiCreditsTotal}',
                subtitle:
                    '${(summary.aiCreditsUsed / summary.aiCreditsTotal * 100).round()}% used',
                accentColor: Colors.purpleAccent,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          RecentActivityCard(items: summary.recentActivity),
        ],
      ),
    );
  }
}
