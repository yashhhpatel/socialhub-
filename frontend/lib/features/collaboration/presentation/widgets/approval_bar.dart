import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../auth/presentation/state/current_user_provider.dart';
import '../../data/repositories/api_collaboration_repository.dart';
import '../../domain/entities/approval_status.dart';

/// A strip above the canvas (Milestone 13.3): the design's approval status
/// plus the role-gated actions available in that state. An editor can submit
/// or withdraw; only an admin sees Approve/Reject on a pending design.
class ApprovalBar extends ConsumerWidget {
  const ApprovalBar({super.key, required this.assetId});

  final String assetId;

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    ApprovalStatus target,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(collaborationRepositoryProvider).changeApproval(assetId, target);
      ref.invalidate(approvalStatusProvider(assetId));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update approval: ${describeApiError(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(approvalStatusProvider(assetId));
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return statusAsync.maybeWhen(
      data: (status) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.sm,
        ),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            _StatusChip(status: status),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Text(
                _hint(status),
                style: theme.textTheme.bodySmall,
              ),
            ),
            ...userAsync.maybeWhen(
              data: (user) => _actionsFor(context, ref, status, isAdmin: user.isAdmin),
              orElse: () => const [],
            ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  String _hint(ApprovalStatus status) => switch (status) {
        ApprovalStatus.draft => 'Submit this design when it is ready for review.',
        ApprovalStatus.pendingApproval => 'Waiting for an admin to approve or reject.',
        ApprovalStatus.approved => 'Approved — ready to publish.',
        ApprovalStatus.rejected => 'Changes requested. Edit and resubmit.',
      };

  List<Widget> _actionsFor(
    BuildContext context,
    WidgetRef ref,
    ApprovalStatus status, {
    required bool isAdmin,
  }) {
    switch (status) {
      case ApprovalStatus.draft:
      case ApprovalStatus.rejected:
        return [
          FilledButton(
            onPressed: () => _change(context, ref, ApprovalStatus.pendingApproval),
            child: const Text('Submit for approval'),
          ),
        ];
      case ApprovalStatus.pendingApproval:
        if (!isAdmin) return const [];
        return [
          OutlinedButton(
            onPressed: () => _change(context, ref, ApprovalStatus.rejected),
            child: const Text('Reject'),
          ),
          const SizedBox(width: SpacingTokens.sm),
          FilledButton(
            onPressed: () => _change(context, ref, ApprovalStatus.approved),
            child: const Text('Approve'),
          ),
        ];
      case ApprovalStatus.approved:
        return [
          TextButton(
            onPressed: () => _change(context, ref, ApprovalStatus.draft),
            child: const Text('Withdraw'),
          ),
        ];
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color color, IconData icon) = switch (status) {
      ApprovalStatus.draft => (scheme.onSurfaceVariant, Icons.edit_outlined),
      ApprovalStatus.pendingApproval => (Colors.orange.shade700, Icons.hourglass_top),
      ApprovalStatus.approved => (Colors.green.shade700, Icons.check_circle_outline),
      ApprovalStatus.rejected => (scheme.error, Icons.cancel_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
