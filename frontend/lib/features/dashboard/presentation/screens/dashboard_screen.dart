import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/staggered_item.dart';
import '../../../../core/motion/tap_scale.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/theme/platform_style.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../scheduler/domain/entities/scheduled_job.dart';
import '../../../scheduler/presentation/state/scheduler_controller.dart';
import '../../data/api_dashboard_repository.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../widgets/greeting_header.dart';
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
          const GreetingHeader(),
          const SizedBox(height: SpacingTokens.lg),
          Text('Overview', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Here\'s what\'s happening across your connected platforms.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
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
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.md),
          const _QuickActions(),
          const SizedBox(height: SpacingTokens.lg),
          // Recent activity + upcoming posts side-by-side on wide screens,
          // stacked on mobile.
          if (Breakpoints.isMobile(context)) ...[
            RecentActivityCard(items: summary.recentActivity),
            const SizedBox(height: SpacingTokens.lg),
            const _UpcomingPosts(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RecentActivityCard(items: summary.recentActivity),
                ),
                const SizedBox(width: SpacingTokens.lg),
                const Expanded(child: _UpcomingPosts()),
              ],
            ),
        ],
      ),
    );
  }
}

/// Fast links into the core flow. Purely navigation — actual mutating actions
/// on those pages are still gated by auth at the network layer.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    (Icons.add_photo_alternate_outlined, 'New post', '/content'),
    (Icons.calendar_month_outlined, 'Schedule', '/calendar'),
    (Icons.insights_outlined, 'Analytics', '/analytics'),
    (Icons.perm_media_outlined, 'Media', '/media-library'),
  ];

  @override
  Widget build(BuildContext context) {
    final cols = Breakpoints.isDesktop(context)
        ? 4
        : Breakpoints.isTablet(context)
            ? 4
            : 2;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: SpacingTokens.md,
      mainAxisSpacing: SpacingTokens.md,
      childAspectRatio: 2.4,
      children: [
        for (var i = 0; i < _actions.length; i++)
          StaggeredItem(
            index: i,
            child: _QuickActionCard(
              icon: _actions[i].$1,
              label: _actions[i].$2,
              path: _actions[i].$3,
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TapScale(
      hoverElevation: true,
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.go(path),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Upcoming posts, sourced from the real GET /publish/jobs (the same provider
/// the Calendar uses) — the still-in-flight jobs, soonest first. No mock data.
class _UpcomingPosts extends ConsumerWidget {
  const _UpcomingPosts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobsAsync = ref.watch(schedulerJobsProvider);

    Widget shell(Widget child) => Container(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upcoming posts',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/calendar'),
                    child: const Text('Calendar'),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.sm),
              child,
            ],
          ),
        );

    return jobsAsync.when(
      loading: () => shell(
        const Padding(
          padding: EdgeInsets.all(SpacingTokens.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => shell(
        Text(
          'Could not load upcoming posts.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      data: (jobs) {
        final upcoming = jobs.where((j) => j.isInFlight).toList()
          ..sort((a, b) {
            final at = a.scheduledAt ?? a.createdAt;
            final bt = b.scheduledAt ?? b.createdAt;
            return at.compareTo(bt);
          });
        if (upcoming.isEmpty) {
          return shell(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SpacingTokens.md),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  Text(
                    'Nothing scheduled yet',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Schedule a post and it will appear here.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return shell(
          Column(
            children: [
              for (final job in upcoming.take(5)) _UpcomingRow(job: job),
            ],
          ),
        );
      },
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.job});
  final ScheduledJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = PlatformStyle.color(job.platform, theme.colorScheme);
    final when = (job.scheduledAt ?? job.createdAt).toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final mm = when.minute.toString().padLeft(2, '0');
    final label = '${when.day} ${months[when.month - 1]} · ${when.hour}:$mm';

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child:
                Icon(PlatformStyle.icon(job.platform), size: 18, color: color),
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PlatformStyle.label(job.platform),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            job.status.name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
