import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';

/// Admin → System (Phase 21.10): deep health (DB + Redis), BullMQ queue stats,
/// and recent 4xx/5xx.
class AdminSystemScreen extends ConsumerWidget {
  const AdminSystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final health = ref.watch(adminHealthProvider);
    final queues = ref.watch(adminQueuesProvider);
    final errors = ref.watch(adminErrorsProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('System', style: theme.textTheme.headlineLarge),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(adminHealthProvider);
                  ref.invalidate(adminQueuesProvider);
                  ref.invalidate(adminErrorsProvider);
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Health
          health.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(describeApiError(e), style: theme.textTheme.bodySmall),
            data: (h) => Wrap(
              spacing: SpacingTokens.sm,
              runSpacing: SpacingTokens.sm,
              children: [
                _HealthChip(label: 'Database', ok: h.db),
                _HealthChip(label: 'Redis', ok: h.redis),
                _HealthChip(label: 'Sentry', ok: h.sentryConfigured, neutralWhenOff: true),
                Chip(label: Text('Uptime: ${_uptime(h.uptimeSeconds)}')),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Queues
          Text('Queues', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.sm),
          queues.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(describeApiError(e), style: theme.textTheme.bodySmall),
            data: (list) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Queue')),
                  DataColumn(label: Text('Waiting'), numeric: true),
                  DataColumn(label: Text('Active'), numeric: true),
                  DataColumn(label: Text('Completed'), numeric: true),
                  DataColumn(label: Text('Failed'), numeric: true),
                  DataColumn(label: Text('Delayed'), numeric: true),
                ],
                rows: [
                  for (final q in list)
                    DataRow(
                      cells: [
                        DataCell(Text(q.name)),
                        DataCell(Text('${q.waiting}')),
                        DataCell(Text('${q.active}')),
                        DataCell(Text('${q.completed}')),
                        DataCell(
                          Text(
                            '${q.failed}',
                            style: TextStyle(
                              color: q.failed > 0 ? AppColors.error : null,
                            ),
                          ),
                        ),
                        DataCell(Text('${q.delayed}')),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Recent errors
          Text('Recent errors (4xx/5xx)', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.sm),
          errors.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(describeApiError(e), style: theme.textTheme.bodySmall),
            data: (list) {
              if (list.isEmpty) {
                return Text('No recent errors.', style: theme.textTheme.bodyMedium);
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('When')),
                    DataColumn(label: Text('Status'), numeric: true),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('Path')),
                    DataColumn(label: Text('Actor')),
                  ],
                  rows: [
                    for (final e in list)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              e.createdAt
                                      ?.toIso8601String()
                                      .replaceFirst('T', ' ')
                                      .split('.')
                                      .first ??
                                  '',
                            ),
                          ),
                          DataCell(
                            Text(
                              '${e.statusCode}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                          DataCell(Text(e.method)),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(
                                e.path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(e.actorEmail)),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _uptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({
    required this.label,
    required this.ok,
    this.neutralWhenOff = false,
  });
  final String label;
  final bool ok;
  final bool neutralWhenOff;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? AppColors.success
        : (neutralWhenOff ? AppColors.textMuted : AppColors.error);
    return Chip(
      avatar: Icon(
        ok ? Icons.check_circle : (neutralWhenOff ? Icons.remove_circle_outline : Icons.error),
        color: color,
        size: 18,
      ),
      label: Text('$label: ${ok ? 'OK' : (neutralWhenOff ? 'off' : 'DOWN')}'),
    );
  }
}
