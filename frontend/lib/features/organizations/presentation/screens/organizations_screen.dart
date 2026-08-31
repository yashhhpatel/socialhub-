import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/form_skeleton.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/layout/widgets/page_header.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_organizations_repository.dart';

/// Organization overview + settings hub. Shows the org's name, plan, size and
/// approval policy, and links out to the org-management surfaces (team,
/// branding, connected accounts) so they're discoverable in one place.
class OrganizationsScreen extends ConsumerWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orgAsync = ref.watch(orgOverviewProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Organization',
            subtitle: 'Your workspace at a glance, and everything that manages it.',
          ),
          const SizedBox(height: SpacingTokens.lg),
          orgAsync.when(
            loading: () => const FormSkeleton(),
            // Logged out: skip the data-only overview card entirely (rather
            // than a blocking wall) — the page's header and the Manage links
            // below stay fully browsable.
            error: (e, _) => isUnauthorized(e)
                ? const SizedBox.shrink()
                : Text(
                    'Could not load your organization: ${describeApiError(e)}',),
            data: (org) => _Overview(org: org),
          ),
          const SizedBox(height: SpacingTokens.lg),
          Text('Manage', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.sm),
          const _ManageGrid(),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.org});

  final OrgOverview org;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  org.name.isNotEmpty ? org.name[0].toUpperCase() : '?',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Text(org.name, style: theme.textTheme.titleLarge),
              ),
              Chip(
                  label: Text(
                      '${org.planTier[0].toUpperCase()}${org.planTier.substring(1)} plan',),),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Wrap(
            spacing: SpacingTokens.lg,
            runSpacing: SpacingTokens.sm,
            children: [
              _Stat(label: 'Members', value: '${org.memberCount}'),
              _Stat(
                label: 'Approval required',
                value: org.requiresApproval ? 'On' : 'Off',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ManageGrid extends StatelessWidget {
  const _ManageGrid();

  static const _links = [
    (icon: Icons.people_outline, label: 'Team & roles', route: '/team'),
    (
      icon: Icons.format_paint_outlined,
      label: 'White label',
      route: '/white-label'
    ),
    (icon: Icons.palette_outlined, label: 'Brand kit', route: '/brand-kit'),
    (icon: Icons.link, label: 'Connected accounts', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: SpacingTokens.md,
      runSpacing: SpacingTokens.md,
      children: [
        for (final link in _links)
          SizedBox(
            width: 220,
            // Fixed height so every card matches regardless of whether its
            // label wraps to a second line (e.g. "Connected accounts").
            height: 60,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go(link.route),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(link.icon, color: theme.colorScheme.primary),
                    const SizedBox(width: SpacingTokens.sm),
                    Expanded(
                      child: Text(
                        link.label,
                        style: theme.textTheme.bodyLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
