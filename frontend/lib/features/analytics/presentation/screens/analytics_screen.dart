import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../domain/entities/analytics_overview.dart';
import '../state/analytics_controller.dart';

/// Unified analytics dashboard (Milestone 10.4): cross-platform performance
/// in one view — headline totals, a per-platform comparison (bar chart +
/// table), and the top posts by engagement.
///
/// Charts are built from plain widgets rather than a charting package: the
/// data is a small per-platform breakdown (a handful of bars), and a
/// FractionallySizedBox bar is more robust on the project's pinned Flutter
/// SDK than pulling in a chart dependency for so little.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analytics', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: SpacingTokens.xs),
                    Text(
                      'Performance across every connected platform.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              overviewAsync.maybeWhen(
                data: (o) => _LastUpdated(at: o.lastUpdated),
                orElse: () => const SizedBox.shrink(),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(analyticsOverviewProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          overviewAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            // Logged out: show the normal empty analytics state (browsable).
            error: (error, _) => isUnauthorized(error)
                ? const _EmptyAnalytics()
                : _AnalyticsError(
                    message: describeApiError(error),
                    onRetry: () => ref.invalidate(analyticsOverviewProvider),
                  ),
            data: (overview) => overview.isEmpty
                ? const _EmptyAnalytics()
                : _Dashboard(overview: overview),
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.overview});

  final AnalyticsOverview overview;

  @override
  Widget build(BuildContext context) {
    final t = overview.totals;
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Wrap(
          spacing: SpacingTokens.md,
          runSpacing: SpacingTokens.md,
          children: [
            _StatTile(label: 'Impressions', value: t.impressions, icon: Icons.visibility_outlined),
            _StatTile(label: 'Reach', value: t.reach, icon: Icons.groups_outlined),
            _StatTile(label: 'Engagement', value: t.engagement, icon: Icons.favorite_outline),
            _StatTile(label: 'Posts', value: overview.postCount, icon: Icons.article_outlined),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        _Section(
          title: 'Impressions by platform',
          child: _PlatformBarChart(breakdowns: overview.byPlatform),
        ),
        const SizedBox(height: SpacingTokens.lg),
        _Section(
          title: 'Platform comparison',
          child: _ComparisonTable(breakdowns: overview.byPlatform),
        ),
        const SizedBox(height: SpacingTokens.lg),
        _Section(
          title: 'Top posts',
          child: _TopPosts(posts: overview.topPosts),
        ),
      ],
    );
  }
}

String _platformLabel(String p) => '${p[0].toUpperCase()}${p.substring(1)}';

/// A stable, distinct colour per platform for the bars and legend.
Color _platformColor(String platform, ColorScheme scheme) {
  switch (platform) {
    case 'instagram':
      return const Color(0xFFE1306C);
    case 'facebook':
      return const Color(0xFF1877F2);
    case 'threads':
      return const Color(0xFF444444);
    case 'x':
      return const Color(0xFF1DA1F2);
    case 'linkedin':
      return const Color(0xFF0A66C2);
    default:
      return scheme.primary;
  }
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: SpacingTokens.sm),
          Text(_compact(value), style: theme.textTheme.headlineSmall),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PlatformBarChart extends StatelessWidget {
  const _PlatformBarChart({required this.breakdowns});

  final List<PlatformBreakdown> breakdowns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = breakdowns.fold<int>(
      1,
      (m, b) => b.metrics.impressions > m ? b.metrics.impressions : m,
    );

    return Column(
      children: [
        for (final b in breakdowns)
          Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(_platformLabel(b.platform), style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (b.metrics.impressions / max).clamp(0.0, 1.0),
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: _platformColor(b.platform, theme.colorScheme),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SpacingTokens.sm),
                SizedBox(
                  width: 56,
                  child: Text(
                    _compact(b.metrics.impressions),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.breakdowns});

  final List<PlatformBreakdown> breakdowns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head = theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: head,
        columns: const [
          DataColumn(label: Text('Platform')),
          DataColumn(label: Text('Posts'), numeric: true),
          DataColumn(label: Text('Impressions'), numeric: true),
          DataColumn(label: Text('Likes'), numeric: true),
          DataColumn(label: Text('Comments'), numeric: true),
          DataColumn(label: Text('Shares'), numeric: true),
          DataColumn(label: Text('Engagement'), numeric: true),
        ],
        rows: [
          for (final b in breakdowns)
            DataRow(
              cells: [
                DataCell(Text(_platformLabel(b.platform))),
                DataCell(Text('${b.postCount}')),
                DataCell(Text(_compact(b.metrics.impressions))),
                DataCell(Text(_compact(b.metrics.likes))),
                DataCell(Text(_compact(b.metrics.comments))),
                DataCell(Text(_compact(b.metrics.shares))),
                DataCell(Text(_compact(b.metrics.engagement))),
              ],
            ),
        ],
      ),
    );
  }
}

class _TopPosts extends StatelessWidget {
  const _TopPosts({required this.posts});

  final List<TopPost> posts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (posts.isEmpty) return const Text('No posts with metrics yet.');

    return Column(
      children: [
        for (final p in posts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: _platformColor(p.platform, theme.colorScheme),
              radius: 6,
            ),
            title: Text('${_platformLabel(p.platform)} · post ${p.externalPostId ?? p.publishJobId}'),
            subtitle: Text(
              '${_compact(p.metrics.impressions)} impressions · '
              '${_compact(p.metrics.likes)} likes · ${_compact(p.metrics.comments)} comments',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              '${_compact(p.engagementScore)} eng.',
              style: theme.textTheme.labelLarge,
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.md),
          child,
        ],
      ),
    );
  }
}

class _LastUpdated extends StatelessWidget {
  const _LastUpdated({required this.at});

  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    if (at == null) return const SizedBox.shrink();
    final local = at!.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(right: SpacingTokens.sm),
      child: Text(
        'Updated ${local.day}/${local.month} $hh:$mm',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: SpacingTokens.md),
          Text('No analytics yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Publish to a connected account — metrics appear here after the next pull.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load analytics: $message'),
          const SizedBox(height: SpacingTokens.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
