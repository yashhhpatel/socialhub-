import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_publish_job.dart';

const _statusFilters = <String>[
  '',
  'queued',
  'scheduled',
  'processing',
  'published',
  'failed',
  'cancelled',
];

/// Admin → Content & publishing (Phase 21.7): the cross-tenant publish pipeline
/// with a failed-jobs triage queue and retry/cancel actions.
class AdminPublishingScreen extends ConsumerStatefulWidget {
  const AdminPublishingScreen({super.key});

  @override
  ConsumerState<AdminPublishingScreen> createState() =>
      _AdminPublishingScreenState();
}

class _AdminPublishingScreenState extends ConsumerState<AdminPublishingScreen> {
  String _status = '';
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String ok) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(ok)));
      ref.invalidate(adminPublishJobsProvider(_status));
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
    final async = ref.watch(adminPublishJobsProvider(_status));

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Content & publishing', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Publish pipeline across all organizations. Filter to failed for '
            'support triage; retry or cancel a job.',
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
                      ref.invalidate(adminPublishJobsProvider(_status)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
            data: (list) => _Table(
              list: list,
              busy: _busy,
              onRetry: (j) =>
                  _run(() => repo.retryPublishJob(j.id), 'Job re-queued.'),
              onCancel: (j) =>
                  _run(() => repo.cancelPublishJob(j.id), 'Job cancelled.'),
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
    required this.onRetry,
    required this.onCancel,
  });

  final AdminPublishJobList list;
  final bool busy;
  final void Function(AdminPublishJob) onRetry;
  final void Function(AdminPublishJob) onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (list.data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: SpacingTokens.lg),
        child: Text('No publish jobs.', style: theme.textTheme.bodyMedium),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${list.total} total', style: theme.textTheme.bodySmall),
        const SizedBox(height: SpacingTokens.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Org')),
              DataColumn(label: Text('Platform')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Attempts'), numeric: true),
              DataColumn(label: Text('Last error')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final j in list.data)
                DataRow(
                  cells: [
                    DataCell(Text(j.orgName)),
                    DataCell(Text(j.platform)),
                    DataCell(Text(j.status)),
                    DataCell(Text('${j.attemptCount}')),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          j.lastError ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Retry',
                            visualDensity: VisualDensity.compact,
                            onPressed: (busy || j.isPublished)
                                ? null
                                : () => onRetry(j),
                            icon: const Icon(Icons.replay, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Cancel',
                            visualDensity: VisualDensity.compact,
                            onPressed: (busy || j.isPublished)
                                ? null
                                : () => onCancel(j),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
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
