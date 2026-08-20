import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../ai_suite/data/repositories/api_ai_suite_repository.dart';
import '../../domain/entities/scheduled_job.dart';
import '../state/scheduler_controller.dart';

/// The content calendar (Milestone 7.4) — an agenda of upcoming scheduled
/// posts and recent publish history, with live status.
///
/// A list/agenda rather than a month grid: what a user acts on is "what is
/// going out next and did the last batch land", which reads better as a
/// time-ordered list than as cells. A month grid is a reasonable future
/// enhancement, not what this milestone needs.
class SchedulerScreen extends ConsumerStatefulWidget {
  const SchedulerScreen({super.key});

  @override
  ConsumerState<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends ConsumerState<SchedulerScreen> {
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Polls while anything is still in flight, and stops once everything has
  /// reached a terminal state — no point hitting the API on a static list.
  void _syncPolling(List<ScheduledJob> jobs) {
    final anyInFlight = jobs.any((j) => j.isInFlight);
    if (anyInFlight && _poll == null) {
      _poll = Timer.periodic(
        const Duration(seconds: 10),
        (_) => ref.invalidate(schedulerJobsProvider),
      );
    } else if (!anyInFlight && _poll != null) {
      _poll!.cancel();
      _poll = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(schedulerJobsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Calendar', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: SpacingTokens.xs),
                    Text(
                      'Everything scheduled and recently published, across platforms.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(schedulerJobsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          const _BestTimesBar(),
          const SizedBox(height: SpacingTokens.md),
          jobsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            // Logged out: show the normal empty calendar (browsable).
            error: (error, _) => isUnauthorized(error)
                ? const _EmptyCalendar()
                : _SchedulerError(
                    message: describeApiError(error),
                    onRetry: () => ref.invalidate(schedulerJobsProvider),
                  ),
            data: (jobs) {
              _syncPolling(jobs);
              if (jobs.isEmpty) return const _EmptyCalendar();
              return _JobAgenda(jobs: jobs);
            },
          ),
        ],
      ),
    );
  }
}

/// AI best-time-to-post suggestions (Milestone 12.3): a compact row of the
/// org's historically strongest posting slots. Silent until there's enough
/// history to recommend from — an empty result, an error, or the loading
/// state all render nothing rather than nagging.
class _BestTimesBar extends ConsumerWidget {
  const _BestTimesBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slots = ref.watch(bestTimesProvider);

    return slots.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: SpacingTokens.sm,
          runSpacing: SpacingTokens.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: SpacingTokens.xs),
                Text('Best times to post', style: theme.textTheme.labelLarge),
              ],
            ),
            for (final slot in list)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(slot.localLabel),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _JobAgenda extends ConsumerWidget {
  const _JobAgenda({required this.jobs});

  final List<ScheduledJob> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Upcoming first (soonest scheduled at the top), then everything else by
    // recency — the two questions a user has, in the order they have them.
    final upcoming = jobs.where((j) => j.isInFlight).toList()
      ..sort((a, b) {
        final at = a.scheduledAt ?? a.createdAt;
        final bt = b.scheduledAt ?? b.createdAt;
        return at.compareTo(bt);
      });
    final history = jobs.where((j) => !j.isInFlight).toList();

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        if (upcoming.isNotEmpty) ...[
          const _SectionHeader('Upcoming'),
          for (final job in upcoming) _JobTile(job: job),
          const SizedBox(height: SpacingTokens.lg),
        ],
        if (history.isNotEmpty) ...[
          const _SectionHeader('History'),
          for (final job in history) _JobTile(job: job),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _JobTile extends ConsumerWidget {
  const _JobTile({required this.job});

  final ScheduledJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _platformLabel(job.platform),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(width: SpacingTokens.sm),
                      _StatusChip(status: job.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_subtitle(job), style: theme.textTheme.bodySmall),
                  if (job.status == ScheduledJobStatus.failed &&
                      job.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      job.lastError!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            if (job.isCancellable)
              TextButton(
                onPressed: () => _confirmCancel(context, ref),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel scheduled post?'),
        content: const Text('It will not be published. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel post'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(cancelJobProvider)(job.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: ${describeApiError(error)}')),
      );
    }
  }

  String _subtitle(ScheduledJob job) {
    switch (job.status) {
      case ScheduledJobStatus.scheduled:
        return 'Scheduled for ${_formatWhen(job.scheduledAt!)}';
      case ScheduledJobStatus.queued:
      case ScheduledJobStatus.processing:
        return 'Publishing now…';
      case ScheduledJobStatus.published:
        return 'Published';
      case ScheduledJobStatus.failed:
        return 'Failed after ${job.attemptCount} attempt${job.attemptCount == 1 ? '' : 's'}';
      case ScheduledJobStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ScheduledJobStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color fg, String label) = switch (status) {
      ScheduledJobStatus.scheduled => (scheme.primary, 'Scheduled'),
      ScheduledJobStatus.queued => (scheme.primary, 'Queued'),
      ScheduledJobStatus.processing => (scheme.primary, 'Publishing'),
      ScheduledJobStatus.published => (Colors.green.shade700, 'Published'),
      ScheduledJobStatus.failed => (scheme.error, 'Failed'),
      ScheduledJobStatus.cancelled => (scheme.onSurfaceVariant, 'Cancelled'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyCalendar extends StatelessWidget {
  const _EmptyCalendar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: SpacingTokens.md),
          Text('Nothing scheduled yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Schedule a post from the publish dialog and it will appear here.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SchedulerError extends StatelessWidget {
  const _SchedulerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load your calendar: $message'),
          const SizedBox(height: SpacingTokens.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _platformLabel(String platform) =>
    '${platform[0].toUpperCase()}${platform.substring(1)}';

const _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatWhen(DateTime instant) {
  final local = instant.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]} at ${local.hour}:$minute';
}
