import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';

/// Admin → Compliance (Phase 21.9): the Meta data-deletion request queue.
/// (Workspace suspension lives on the organization detail page.)
class AdminComplianceScreen extends ConsumerWidget {
  const AdminComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(adminDataDeletionProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compliance', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Meta data-deletion requests. Workspace suspension is on an '
            "organization's detail page.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          Text('Data-deletion requests', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.sm),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: SpacingTokens.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              describeApiError(error),
              style: theme.textTheme.bodySmall,
            ),
            data: (list) {
              if (list.data.isEmpty) {
                return Text(
                  'No data-deletion requests.',
                  style: theme.textTheme.bodyMedium,
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('When')),
                    DataColumn(label: Text('Platform')),
                    DataColumn(label: Text('Confirmation code')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final r in list.data)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              r.createdAt?.toIso8601String().split('T').first ??
                                  '',
                            ),
                          ),
                          DataCell(Text(r.platform)),
                          DataCell(Text(r.confirmationCode)),
                          DataCell(Text(r.status)),
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
}
