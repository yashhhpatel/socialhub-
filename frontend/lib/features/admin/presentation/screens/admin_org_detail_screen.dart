import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_organization.dart';

/// Admin → Organization detail (Phase 21.3): plan, members, usage vs limits,
/// and activity for one tenant. Read-only; no secrets.
class AdminOrgDetailScreen extends ConsumerWidget {
  const AdminOrgDetailScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(adminOrganizationProvider(orgId));

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/admin/organizations'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Organizations'),
          ),
          const SizedBox(height: SpacingTokens.sm),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(describeApiError(error), style: theme.textTheme.bodyMedium),
                const SizedBox(height: SpacingTokens.sm),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(adminOrganizationProvider(orgId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
            data: (o) => _Detail(
              org: o,
              onToggleSuspend: () async {
                final messenger = ScaffoldMessenger.of(context);
                final repo = ref.read(adminRepositoryProvider);
                final suspend = o.status != 'suspended';
                try {
                  if (suspend) {
                    await repo.suspendOrg(o.id);
                  } else {
                    await repo.reactivateOrg(o.id);
                  }
                  ref.invalidate(adminOrganizationProvider(orgId));
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(suspend ? 'Workspace suspended.' : 'Workspace reactivated.'),
                    ),
                  );
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed: ${describeApiError(error)}')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.org, required this.onToggleSuspend});

  final AdminOrgDetail org;
  final VoidCallback onToggleSuspend;

  String _limit(int v) => v < 0 ? '∞' : '$v';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suspended = org.status == 'suspended';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(org.name, style: theme.textTheme.headlineLarge),
            ),
            OutlinedButton.icon(
              onPressed: onToggleSuspend,
              icon: Icon(
                suspended ? Icons.play_circle_outline : Icons.block,
                size: 18,
              ),
              style: suspended
                  ? null
                  : OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
              label: Text(suspended ? 'Reactivate' : 'Suspend'),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.xs),
        Wrap(
          spacing: SpacingTokens.sm,
          children: [
            Chip(label: Text('Plan: ${org.planTier}')),
            Chip(label: Text('Subscription: ${org.subscriptionStatus ?? '—'}')),
            if (suspended)
              Chip(
                label: const Text('Suspended'),
                backgroundColor: theme.colorScheme.error.withOpacity(0.15),
              ),
            if (org.requiresApproval) const Chip(label: Text('Approval required')),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),

        _SectionCard(
          title: 'Usage vs limits',
          child: Column(
            children: [
              _UsageRow(
                label: 'Social accounts',
                used: org.usage['socialAccounts'] ?? 0,
                limit: _limit(org.limits['maxSocialAccounts'] ?? 0),
              ),
              _UsageRow(
                label: 'Team members',
                used: org.usage['teamMembers'] ?? 0,
                limit: _limit(org.limits['maxTeamMembers'] ?? 0),
              ),
              _UsageRow(
                label: 'AI credits (month)',
                used: org.usage['aiCreditsUsed'] ?? 0,
                limit: _limit(org.limits['aiCreditsPerMonth'] ?? 0),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.md),

        _SectionCard(
          title: 'Activity',
          child: Wrap(
            spacing: SpacingTokens.lg,
            runSpacing: SpacingTokens.sm,
            children: [
              _Metric('Connected', org.activity['connectedAccounts'] ?? 0),
              _Metric('Drafts', org.activity['drafts'] ?? 0),
              _Metric('Scheduled', org.activity['scheduledPosts'] ?? 0),
              _Metric('Published', org.activity['publishedPosts'] ?? 0),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.md),

        _SectionCard(
          title: 'Members (${org.members.length})',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Verified')),
                DataColumn(label: Text('MFA')),
                DataColumn(label: Text('Platform admin')),
              ],
              rows: [
                for (final m in org.members)
                  DataRow(
                    cells: [
                      DataCell(Text(m.email)),
                      DataCell(Text(m.role)),
                      DataCell(_boolIcon(m.emailVerified)),
                      DataCell(_boolIcon(m.mfaEnabled)),
                      DataCell(Text(m.isPlatformAdmin ? 'Yes' : '')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _boolIcon(bool value) =>
    Icon(value ? Icons.check : Icons.close, size: 16);

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.used, required this.limit});
  final String label;
  final int used;
  final String limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text('$used / $limit', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
