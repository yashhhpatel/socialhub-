import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_organization.dart';

/// Admin → Organizations (Phase 21.3): searchable, paginated tenant list.
class AdminOrganizationsScreen extends ConsumerStatefulWidget {
  const AdminOrganizationsScreen({super.key});

  @override
  ConsumerState<AdminOrganizationsScreen> createState() =>
      _AdminOrganizationsScreenState();
}

class _AdminOrganizationsScreenState
    extends ConsumerState<AdminOrganizationsScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  int _page = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    setState(() {
      _search = _searchController.text.trim();
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(
      adminOrganizationsProvider((search: _search, page: _page)),
    );

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Organizations', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by name',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              FilledButton(onPressed: _applySearch, child: const Text('Search')),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _Error(
              message: describeApiError(error),
              onRetry: () => ref.invalidate(
                adminOrganizationsProvider((search: _search, page: _page)),
              ),
            ),
            data: (list) => _Table(
              list: list,
              onOpen: (id) => context.go('/admin/organizations/$id'),
              onPrev: _page > 1 ? () => setState(() => _page--) : null,
              onNext: _page < list.totalPages
                  ? () => setState(() => _page++)
                  : null,
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
    required this.onOpen,
    required this.onPrev,
    required this.onNext,
  });

  final AdminOrgList list;
  final void Function(String id) onOpen;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (list.data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: SpacingTokens.lg),
        child: Text(
          'No organizations found.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Members'), numeric: true),
              DataColumn(label: Text('Accounts'), numeric: true),
              DataColumn(label: Text('Subscription')),
            ],
            rows: [
              for (final o in list.data)
                DataRow(
                  onSelectChanged: (_) => onOpen(o.id),
                  cells: [
                    DataCell(Text(o.name)),
                    DataCell(Text(o.planTier)),
                    DataCell(Text('${o.memberCount}')),
                    DataCell(Text('${o.socialAccountCount}')),
                    DataCell(Text(o.subscriptionStatus ?? '—')),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.md),
        Row(
          children: [
            Text(
              '${list.total} total · page ${list.page} of '
              '${list.totalPages == 0 ? 1 : list.totalPages}',
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous',
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next',
            ),
          ],
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(message, style: theme.textTheme.bodySmall),
        const SizedBox(height: SpacingTokens.sm),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
