import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/skeleton.dart';
import '../../../../core/motion/staggered_item.dart';
import '../../../../core/motion/tap_scale.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../dashboard/data/api_dashboard_repository.dart';
import '../../../dashboard/domain/entities/dashboard_summary.dart';
import '../../../dashboard/presentation/widgets/greeting_header.dart';
import '../../../dashboard/presentation/widgets/stat_card.dart';
import '../widgets/home_info_sections.dart';

/// The app Home (`/`) — a clean SocialHub overview shown to everyone, signed in
/// or out: a welcome, a real-data overview (reusing the dashboard summary), and
/// quick-navigation cards into the product. Distinct from `/dashboard`, which
/// keeps its detailed view.
///
/// Reuses existing pieces only (GreetingHeader, StatCard, dashboard summary
/// API, theme, motion). No new endpoints or business logic.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authTokenStoreProvider) != null;
    // AppShell already provides the scroll view; keep this a plain column.
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaggeredItem(index: 0, child: _Welcome(loggedIn: loggedIn)),
          const SizedBox(height: SpacingTokens.xl),
          const StaggeredItem(index: 1, child: _OverviewSection()),
          const SizedBox(height: SpacingTokens.xl),
          const StaggeredItem(index: 2, child: _QuickNav()),
          const SizedBox(height: SpacingTokens.xxl),
          // "What SocialHub is and does" — informational sections so a new
          // visitor understands the product without navigating away.
          HomeInfoSections(loggedIn: loggedIn),
        ],
      ),
    );
  }
}

/// Personalised greeting for signed-in users; a welcome + CTAs for visitors.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.loggedIn});
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GreetingHeader(),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Your SocialHub at a glance.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome to SocialHub', style: theme.textTheme.headlineLarge),
        const SizedBox(height: SpacingTokens.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Create, schedule, and analyze posts across Instagram, Facebook, '
            'Threads, X and LinkedIn — from one workspace. Explore freely; '
            'sign in when you want to publish.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.md),
        Wrap(
          spacing: SpacingTokens.md,
          runSpacing: SpacingTokens.sm,
          children: [
            FilledButton(
              onPressed: () => context.go('/register'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              ),
              child: const Text('Get started free'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              ),
              child: const Text('Log in'),
            ),
          ],
        ),
      ],
    );
  }
}

/// The real-data overview — reuses GET /dashboard/summary. Handles loading,
/// signed-out, error (retry) and empty states.
class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Overview', style: theme.textTheme.titleLarge),
            ),
            summaryAsync.maybeWhen(
              data: (_) => TextButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Open dashboard'),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        summaryAsync.when(
          loading: () => const _OverviewSkeleton(),
          error: (error, _) => isUnauthorized(error)
              ? const _SignInPrompt()
              : _OverviewError(
                  message: describeApiError(error),
                  onRetry: () => ref.invalidate(dashboardSummaryProvider),
                ),
          data: (summary) => _OverviewStats(summary: summary),
        ),
      ],
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = summary.scheduledPosts == 0 &&
        summary.publishedPosts == 0 &&
        summary.drafts == 0;

    final cards = <Widget>[
      StatCard(
        icon: Icons.schedule,
        label: 'Scheduled',
        value: '${summary.scheduledPosts}',
        accentColor: AppColors.warning,
      ),
      StatCard(
        icon: Icons.check_circle_outline,
        label: 'Published',
        value: '${summary.publishedPosts}',
        accentColor: AppColors.success,
      ),
      StatCard(
        icon: Icons.edit_outlined,
        label: 'Drafts',
        value: '${summary.drafts}',
        accentColor: AppColors.accent,
      ),
      StatCard(
        icon: Icons.link,
        label: 'Connected accounts',
        value: '${summary.connectedAccounts}',
        accentColor: const Color(0xFF1DA1F2),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: SpacingTokens.md,
          runSpacing: SpacingTokens.md,
          children: [
            for (final c in cards) SizedBox(width: 210, child: c),
          ],
        ),
        if (isNew) ...[
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Icon(Icons.rocket_launch_outlined,
                  size: 18, color: theme.colorScheme.onSurfaceVariant,),
              const SizedBox(width: SpacingTokens.sm),
              Flexible(
                child: Text(
                  'Nothing here yet — create your first post to get going.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SpacingTokens.md,
      runSpacing: SpacingTokens.md,
      children: [
        for (var i = 0; i < 4; i++)
          SizedBox(
            width: 210,
            child:
                Skeleton(height: 132, borderRadius: BorderRadius.circular(12)),
          ),
      ],
    );
  }
}

/// Signed-out overview: the numbers need an account.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

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
          Row(
            children: [
              Icon(Icons.insights_outlined,
                  color: theme.colorScheme.onSurfaceVariant,),
              const SizedBox(width: SpacingTokens.sm),
              Text('Sign in to see your overview',
                  style: theme.textTheme.titleMedium,),
            ],
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Your scheduled, published and draft counts appear here once you '
            'log in.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          FilledButton(
            onPressed: () => context.go('/login?from=/'),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

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
          Text("Couldn't load your overview",
              style: theme.textTheme.titleMedium,),
          const SizedBox(height: SpacingTokens.xs),
          Text(message, style: theme.textTheme.bodySmall),
          const SizedBox(height: SpacingTokens.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.title, this.subtitle, this.path, this.color);
  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
  final Color color;
}

/// Quick-navigation cards into the core product areas.
class _QuickNav extends StatelessWidget {
  const _QuickNav();

  static const _items = [
    _NavItem(Icons.grid_view_outlined, 'Content', 'Designs & drafts',
        '/content', AppColors.accent,),
    _NavItem(Icons.calendar_month_outlined, 'Calendar', 'Plan & schedule',
        '/calendar', AppColors.warning,),
    _NavItem(Icons.insights_outlined, 'Analytics', 'Track performance',
        '/analytics', AppColors.success,),
    _NavItem(Icons.perm_media_outlined, 'Create Post & Publish', 'Images & video',
        '/media-library', Color(0xFF1DA1F2),),
    _NavItem(Icons.auto_awesome_outlined, 'AI Assistant', 'Captions & timing',
        '/ai-assistant', AppColors.accentHover,),
    _NavItem(Icons.hub_outlined, 'Connected accounts', 'Link your platforms',
        '/settings', Color(0xFF0A66C2),),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cols = Breakpoints.isDesktop(context)
        ? 3
        : Breakpoints.isTablet(context)
            ? 2
            : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick navigation', style: theme.textTheme.titleLarge),
        const SizedBox(height: SpacingTokens.md),
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: SpacingTokens.md,
          mainAxisSpacing: SpacingTokens.md,
          childAspectRatio: cols == 1 ? 3.4 : 2.1,
          children: [
            for (var i = 0; i < _items.length; i++)
              StaggeredItem(index: i, child: _NavCard(item: _items[i])),
          ],
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.item});
  final _NavItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TapScale(
      hoverElevation: true,
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.go(item.path),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward,
                    size: 18, color: theme.colorScheme.onSurfaceVariant,),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
