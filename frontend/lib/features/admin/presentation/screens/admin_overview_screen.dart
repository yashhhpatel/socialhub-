import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_overview.dart';
import '../widgets/admin_stat_card.dart';

/// Admin Overview (Phase 21.2): cross-tenant KPIs pulled live from
/// `GET /admin/overview`. Real data only — loading / error / retry states.
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(adminOverviewProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Platform-wide metrics across all organizations.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _Error(
              message: describeApiError(error),
              onRetry: () => ref.invalidate(adminOverviewProvider),
            ),
            data: (o) => _Kpis(overview: o),
          ),
        ],
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.overview});

  final AdminOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = overview;
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1200 ? 4 : (width >= 800 ? 3 : 2);

    final cards = <Widget>[
      AdminStatCard(
        label: 'Organizations',
        value: '${o.totalOrganizations}',
        subtitle: '+${o.newOrganizations30d} in 30d',
        icon: Icons.apartment_outlined,
      ),
      AdminStatCard(
        label: 'Users',
        value: '${o.totalUsers}',
        subtitle: '+${o.newUsers30d} in 30d',
        icon: Icons.people_outline,
      ),
      AdminStatCard(
        label: 'Active orgs',
        value: '${o.activeOrganizations}',
        subtitle: 'have a connected account',
        icon: Icons.bolt_outlined,
      ),
      AdminStatCard(
        label: 'Connected accounts',
        value: '${o.connectedAccounts}',
        icon: Icons.link,
      ),
      AdminStatCard(
        label: 'Needs reconnect',
        value: '${o.accountsNeedingReconnect}',
        subtitle: 'expired / revoked / error',
        icon: Icons.link_off,
        highlight: o.accountsNeedingReconnect > 0,
      ),
      AdminStatCard(
        label: 'Published posts',
        value: '${o.publishedPosts}',
        icon: Icons.check_circle_outline,
      ),
      AdminStatCard(
        label: 'Publish failure rate',
        value: '${o.failureRatePercent}%',
        subtitle: '${o.failedPosts} failed',
        icon: Icons.error_outline,
        highlight: o.failureRatePercent >= 20,
      ),
      AdminStatCard(
        label: 'Unverified emails',
        value: '${o.unverifiedUsers}',
        subtitle: '${o.mfaEnabledUsers} have MFA',
        icon: Icons.mark_email_unread_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: SpacingTokens.md,
          mainAxisSpacing: SpacingTokens.md,
          childAspectRatio: 1.7,
          children: cards,
        ),
        const SizedBox(height: SpacingTokens.lg),
        Text('Plans', style: theme.textTheme.titleMedium),
        const SizedBox(height: SpacingTokens.sm),
        Wrap(
          spacing: SpacingTokens.sm,
          runSpacing: SpacingTokens.sm,
          children: [
            for (final p in o.planDistribution)
              Chip(
                label: Text('${_titleCase(p.tier)}: ${p.count}'),
              ),
          ],
        ),
      ],
    );
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
          const SizedBox(height: SpacingTokens.md),
          Text(
            "Couldn't load platform metrics",
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(message, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: SpacingTokens.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
