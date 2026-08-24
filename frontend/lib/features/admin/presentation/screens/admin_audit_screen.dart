import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_audit.dart';

const _methods = <String>['', 'POST', 'PATCH', 'PUT', 'DELETE'];

/// Admin → Audit log (Phase 21.8): the cross-org audit trail with filters.
class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  final _actorController = TextEditingController();
  String _actor = '';
  String _method = '';
  int _page = 1;

  @override
  void dispose() {
    _actorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(
      adminAuditProvider((actorEmail: _actor, method: _method, page: _page)),
    );

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Audit log', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _actorController,
                  decoration: const InputDecoration(
                    hintText: 'Filter by actor email',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => setState(() {
                    _actor = _actorController.text.trim();
                    _page = 1;
                  }),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              DropdownButton<String>(
                value: _method,
                items: [
                  for (final m in _methods)
                    DropdownMenuItem(value: m, child: Text(m.isEmpty ? 'Any method' : m)),
                ],
                onChanged: (v) => setState(() {
                  _method = v ?? '';
                  _page = 1;
                }),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              describeApiError(error),
              style: theme.textTheme.bodySmall,
            ),
            data: (list) => _Table(
              list: list,
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
  const _Table({required this.list, required this.onPrev, required this.onNext});

  final AdminAuditList list;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (list.data.isEmpty) {
      return Text('No audit entries.', style: theme.textTheme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('When')),
              DataColumn(label: Text('Actor')),
              DataColumn(label: Text('Method')),
              DataColumn(label: Text('Path')),
              DataColumn(label: Text('Status'), numeric: true),
            ],
            rows: [
              for (final a in list.data)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        a.createdAt
                                ?.toIso8601String()
                                .replaceFirst('T', ' ')
                                .split('.')
                                .first ??
                            '',
                      ),
                    ),
                    DataCell(Text(a.actorEmail)),
                    DataCell(Text(a.method)),
                    DataCell(
                      SizedBox(
                        width: 260,
                        child: Text(
                          a.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${a.statusCode}',
                        style: TextStyle(
                          color: a.statusCode >= 400
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ),
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
