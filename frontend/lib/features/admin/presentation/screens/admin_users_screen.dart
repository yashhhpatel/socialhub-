import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_user.dart';

/// Admin → Users (Phase 21.4): searchable, paginated user list (by email).
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
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
    final async = ref.watch(adminUsersProvider((search: _search, page: _page)));

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Users', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by email',
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
            error: (error, _) => Column(
              children: [
                Text(describeApiError(error), style: theme.textTheme.bodySmall),
                const SizedBox(height: SpacingTokens.sm),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(
                    adminUsersProvider((search: _search, page: _page)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
            data: (list) => _Table(
              list: list,
              onOpen: (id) => context.go('/admin/users/$id'),
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

  final AdminUserList list;
  final void Function(String id) onOpen;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (list.data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: SpacingTokens.lg),
        child: Text('No users found.', style: theme.textTheme.bodyMedium),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Org')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Verified')),
              DataColumn(label: Text('MFA')),
              DataColumn(label: Text('Sign-in')),
              DataColumn(label: Text('Admin')),
            ],
            rows: [
              for (final u in list.data)
                DataRow(
                  onSelectChanged: (_) => onOpen(u.id),
                  cells: [
                    DataCell(Text(u.email)),
                    DataCell(Text(u.orgName)),
                    DataCell(Text(u.role)),
                    DataCell(_boolIcon(u.emailVerified)),
                    DataCell(_boolIcon(u.mfaEnabled)),
                    DataCell(Text(u.signInMethod)),
                    DataCell(Text(u.isPlatformAdmin ? 'Yes' : '')),
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

Widget _boolIcon(bool value) =>
    Icon(value ? Icons.check : Icons.close, size: 16);
