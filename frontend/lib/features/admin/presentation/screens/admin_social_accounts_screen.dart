import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_social_account.dart';

const _statusFilters = <String>['', 'connected', 'expired', 'revoked', 'error'];

/// Admin → Social accounts (Phase 21.5): the cross-tenant reconnect queue.
class AdminSocialAccountsScreen extends ConsumerStatefulWidget {
  const AdminSocialAccountsScreen({super.key});

  @override
  ConsumerState<AdminSocialAccountsScreen> createState() =>
      _AdminSocialAccountsScreenState();
}

class _AdminSocialAccountsScreenState
    extends ConsumerState<AdminSocialAccountsScreen> {
  String _status = '';
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String ok) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(ok)));
      ref.invalidate(adminSocialAccountsProvider(_status));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: ${describeApiError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.read(adminRepositoryProvider);
    final async = ref.watch(adminSocialAccountsProvider(_status));

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Social accounts', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Connection health across all organizations. Filter to the reconnect '
            'queue and force a refresh where supported.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          Wrap(
            spacing: SpacingTokens.sm,
            children: [
              for (final s in _statusFilters)
                ChoiceChip(
                  label: Text(s.isEmpty ? 'All' : s),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              children: [
                Text(describeApiError(error), style: theme.textTheme.bodySmall),
                const SizedBox(height: SpacingTokens.sm),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(adminSocialAccountsProvider(_status)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
            data: (list) => _Table(
              list: list,
              busy: _busy,
              onRefresh: (a) => _run(
                () => repo.refreshSocialAccount(a.id),
                'Refresh attempted.',
              ),
              onDisconnect: (a) => _run(
                () => repo.disconnectSocialAccount(a.id),
                'Account disconnected.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.list,
    required this.busy,
    required this.onRefresh,
    required this.onDisconnect,
  });

  final AdminSocialAccountList list;
  final bool busy;
  final void Function(AdminSocialAccount) onRefresh;
  final void Function(AdminSocialAccount) onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (list.data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: SpacingTokens.lg),
        child: Text('No social accounts.', style: theme.textTheme.bodyMedium),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${list.total} total',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: SpacingTokens.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Platform')),
              DataColumn(label: Text('Organization')),
              DataColumn(label: Text('Account')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final a in list.data)
                DataRow(
                  cells: [
                    DataCell(Text(a.platform)),
                    DataCell(Text(a.orgName)),
                    DataCell(Text(a.externalAccountId)),
                    DataCell(_StatusChip(status: a.status)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Force refresh',
                            visualDensity: VisualDensity.compact,
                            onPressed: busy ? null : () => onRefresh(a),
                            icon: const Icon(Icons.autorenew, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Disconnect',
                            visualDensity: VisualDensity.compact,
                            onPressed: busy ? null : () => onDisconnect(a),
                            icon: const Icon(Icons.link_off, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final connected = status == 'connected';
    final color = connected ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
