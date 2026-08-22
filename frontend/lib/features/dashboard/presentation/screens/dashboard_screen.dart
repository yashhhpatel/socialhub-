import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/staggered_item.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_dashboard_repository.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../widgets/recent_activity_card.dart';
import '../widgets/stat_card.dart';

/// The real dashboard content — rendered inside AppShell's content area,
/// not a standalone Scaffold (AppShell owns the sidebar/top bar now).
///
/// Data comes from the live `GET /dashboard/summary` endpoint via
/// dashboardSummaryProvider (org-scoped, real PostgreSQL data). The screen
/// handles loading, error (with retry), and empty states; the visual design of
/// the loaded view is unchanged.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return summaryAsync.when(
      loading: () => const _DashboardLoading(),
      error: (error, _) => isUnauthorized(error)
          // Logged out: the page stays reachable (browse-freely), but the
          // data needs an account — show a calm prompt, not a red error.
          ? const _DashboardLoggedOut()
          : _DashboardError(
              message: describeApiError(error),
              onRetry: () => ref.invalidate(dashboardSummaryProvider),
            ),
      data: (summary) => _DashboardContent(summary: summary),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final columns = Breakpoints.isDesktop(context)
        ? 3
        : Breakpoints.isTablet(context)
            ? 2
            : 1;

    return Padding(
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
              StaggeredItem(
                index: 0,
                child: StatCard(
                  icon: Icons.schedule,
                  label: 'Scheduled Posts',
                  value: '${summary.scheduledPosts}',
                ),
              ),
              StaggeredItem(
                index: 1,
                child: StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Published Posts',
                  value: '${summary.publishedPosts}',
                ),
              ),
              StaggeredItem(
                index: 2,
                child: StatCard(
                  icon: Icons.edit_outlined,
                  label: 'Drafts',
                  value: '${summary.drafts}',
                ),
              ),
              StaggeredItem(
                index: 3,
                child: StatCard(
                  icon: Icons.link,
                  label: 'Connected Accounts',
                  value: '${summary.connectedAccounts}',
                  subtitle: 'Manage in Settings',
                ),
              ),
              StaggeredItem(
                index: 4,
                child: StatCard(
                  icon: Icons.auto_awesome_outlined,
                  label: 'AI Credits',
                  value: summary.aiCreditsUnlimited
                      ? '${summary.aiCreditsUsed}'
                      : '${summary.aiCreditsUsed} / ${summary.aiCreditsTotal}',
                  subtitle: summary.aiCreditsUnlimited
                      ? 'Unlimited'
                      : '${summary.aiCreditsTotal == 0 ? 0 : (summary.aiCreditsUsed / summary.aiCreditsTotal * 100).round()}% used',
                ),
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

/// Loading state — a lightweight centered spinner in the content area.
class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(SpacingTokens.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Logged-out state — the dashboard's data is per-account, so invite the user
/// to log in rather than showing an error. Matches the app's browse-freely,
/// gate-actions pattern.
class _DashboardLoggedOut extends StatelessWidget {
  const _DashboardLoggedOut();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.md),
            Text('Your dashboard', style: theme.textTheme.titleMedium),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              'Log in to see your scheduled posts, activity, and usage.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.md),
            FilledButton(
              onPressed: () => context.go('/login?from=/dashboard'),
              child: const Text('Log in'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry action — no fake fallback data is ever shown.
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: SpacingTokens.md),
            Text(
              "Couldn't load your dashboard",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
