import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/skeleton.dart';
import '../../../../core/motion/tap_scale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/theme/platform_style.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../ai_suite/data/repositories/api_ai_suite_repository.dart';
import '../../domain/entities/scheduled_job.dart';
import '../state/scheduler_controller.dart';

/// How the calendar lays the jobs out: a month grid, a week grid, or the
/// original time-ordered agenda.
enum _CalendarView { month, week, list }

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

  /// Which layout the calendar is showing, and the month/week it's focused on.
  _CalendarView _view = _CalendarView.month;
  DateTime _anchor = DateTime.now();

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Moves the focused month or week by [delta] units (or back to today when
  /// [toToday] is set). No-op in list view, which isn't date-anchored.
  void _shift(int delta, {bool toToday = false}) {
    setState(() {
      if (toToday) {
        _anchor = DateTime.now();
      } else if (_view == _CalendarView.week) {
        _anchor = _anchor.add(Duration(days: 7 * delta));
      } else {
        _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
      }
    });
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
            loading: () => const _CalendarSkeleton(),
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CalendarControls(
                    view: _view,
                    anchor: _anchor,
                    onViewChanged: (v) => setState(() => _view = v),
                    onPrev: () => _shift(-1),
                    onNext: () => _shift(1),
                    onToday: () => _shift(0, toToday: true),
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  switch (_view) {
                    _CalendarView.list => _JobAgenda(jobs: jobs),
                    _CalendarView.week =>
                      _WeekCalendar(jobs: jobs, anchor: _anchor),
                    _CalendarView.month =>
                      _MonthCalendar(jobs: jobs, anchor: _anchor),
                  },
                ],
              );
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
                Icon(Icons.schedule,
                    size: 16, color: theme.colorScheme.primary,),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: TapScale(
        hoverElevation: true,
        borderRadius: BorderRadius.circular(10),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
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
      ScheduledJobStatus.scheduled => (AppColors.warning, 'Scheduled'),
      ScheduledJobStatus.queued => (AppColors.warning, 'Queued'),
      ScheduledJobStatus.processing => (AppColors.warning, 'Publishing'),
      ScheduledJobStatus.published => (AppColors.success, 'Published'),
      ScheduledJobStatus.failed => (AppColors.error, 'Failed'),
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
            ?.copyWith(color: fg, fontWeight: FontWeight.w500),
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

String _platformLabel(String platform) => PlatformStyle.label(platform);

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthsLong = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayLabels = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String _formatWhen(DateTime instant) {
  final local = instant.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]} at ${local.hour}:$minute';
}

/// The date a job sits on in the calendar: its scheduled time when it has one,
/// otherwise when it was created (an immediate publish). Date-only, local.
DateTime _jobDate(ScheduledJob job) {
  final local = (job.scheduledAt ?? job.createdAt).toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Groups jobs by the local calendar day they belong to.
Map<DateTime, List<ScheduledJob>> _groupByDay(List<ScheduledJob> jobs) {
  final map = <DateTime, List<ScheduledJob>>{};
  for (final job in jobs) {
    (map[_jobDate(job)] ??= []).add(job);
  }
  return map;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Monday-based start of the week containing [d].
DateTime _weekStart(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return date.subtract(Duration(days: date.weekday - 1));
}

/// Opens the day's jobs in a bottom sheet, reusing the existing job card (with
/// its status and Cancel action) — no separate detail/edit screen exists, and
/// the brief says not to build one.
void _showDaySheet(
  BuildContext context,
  DateTime day,
  List<ScheduledJob> jobs,
) {
  final theme = Theme.of(context);
  final sorted = [...jobs]..sort((a, b) {
      final at = a.scheduledAt ?? a.createdAt;
      final bt = b.scheduledAt ?? b.createdAt;
      return at.compareTo(bt);
    });
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.lg,
          0,
          SpacingTokens.lg,
          SpacingTokens.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_weekdayLabels[day.weekday - 1]} ${day.day} '
              '${_monthsLong[day.month - 1]} ${day.year}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              '${sorted.length} post${sorted.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: SpacingTokens.md),
            Expanded(
              child: ListView(
                controller: controller,
                children: [for (final job in sorted) _JobTile(job: job)],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

int _byScheduledTime(ScheduledJob a, ScheduledJob b) {
  final at = a.scheduledAt ?? a.createdAt;
  final bt = b.scheduledAt ?? b.createdAt;
  return at.compareTo(bt);
}

/// View toggle (Month / Week / List) plus prev / today / next navigation and
/// the focused-period label. Wraps on narrow screens.
class _CalendarControls extends StatelessWidget {
  const _CalendarControls({
    required this.view,
    required this.anchor,
    required this.onViewChanged,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final _CalendarView view;
  final DateTime anchor;
  final ValueChanged<_CalendarView> onViewChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  String _label() {
    if (view == _CalendarView.week) {
      final start = _weekStart(anchor);
      final end = start.add(const Duration(days: 6));
      if (start.month == end.month) {
        return '${start.day} - ${end.day} ${_months[end.month - 1]} ${end.year}';
      }
      return '${start.day} ${_months[start.month - 1]} - '
          '${end.day} ${_months[end.month - 1]} ${end.year}';
    }
    return '${_monthsLong[anchor.month - 1]} ${anchor.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final toggle = SegmentedButton<_CalendarView>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: _CalendarView.month,
          icon: Icon(Icons.calendar_view_month_outlined),
          label: Text('Month'),
        ),
        ButtonSegment(
          value: _CalendarView.week,
          icon: Icon(Icons.calendar_view_week_outlined),
          label: Text('Week'),
        ),
        ButtonSegment(
          value: _CalendarView.list,
          icon: Icon(Icons.view_agenda_outlined),
          label: Text('List'),
        ),
      ],
      selected: {view},
      onSelectionChanged: (s) => onViewChanged(s.first),
    );

    if (view == _CalendarView.list) return toggle;

    return Wrap(
      spacing: SpacingTokens.md,
      runSpacing: SpacingTokens.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        toggle,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
            ),
            TextButton(onPressed: onToday, child: const Text('Today')),
            IconButton(
              tooltip: 'Next',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: SpacingTokens.sm),
            Text(_label(), style: theme.textTheme.titleSmall),
          ],
        ),
      ],
    );
  }
}

/// A month grid: a weekday header over a 7-column grid of day cells, each
/// carrying its posts as platform-icon marks. Tapping a day with posts opens
/// that day's job cards.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.jobs, required this.anchor});

  final List<ScheduledJob> jobs;
  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = _groupByDay(jobs);
    final today = DateTime.now();
    final isMobile = Breakpoints.isMobile(context);

    final first = DateTime(anchor.year, anchor.month, 1);
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-first: Mon(1) -> 0 blanks.
    final totalCells = (((leading + daysInMonth) / 7).ceil()) * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final w in _weekdayLabels)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
                  child: Text(
                    isMobile ? w[0] : w,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: isMobile ? 0.68 : 1.05,
            mainAxisSpacing: SpacingTokens.xs,
            crossAxisSpacing: SpacingTokens.xs,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayNum = index - leading + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(anchor.year, anchor.month, dayNum);
            final dayJobs = byDay[date] ?? const <ScheduledJob>[];
            return _DayCell(
              date: date,
              jobs: dayJobs,
              isToday: _sameDay(date, today),
              compact: isMobile,
              onTap: dayJobs.isEmpty
                  ? null
                  : () => _showDaySheet(context, date, dayJobs),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.jobs,
    required this.isToday,
    required this.compact,
    this.onTap,
  });

  final DateTime date;
  final List<ScheduledJob> jobs;
  final bool isToday;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = [...jobs]..sort(_byScheduledTime);
    final maxVisible = compact ? 3 : 4;
    final visible = sorted.take(maxVisible).toList();
    final extra = sorted.length - visible.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday ? scheme.primary : theme.dividerColor,
          ),
          color: isToday ? scheme.primary.withOpacity(0.08) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                color: isToday ? scheme.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final job in visible)
                    Icon(
                      PlatformStyle.icon(job.platform),
                      size: compact ? 11 : 14,
                      color: PlatformStyle.color(job.platform, scheme),
                    ),
                  if (extra > 0)
                    Text(
                      '+$extra',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A week view: seven day columns on wide screens, a vertical stack of day
/// rows on mobile. Each post is a tappable chip that opens the day's cards.
class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({required this.jobs, required this.anchor});

  final List<ScheduledJob> jobs;
  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
    final byDay = _groupByDay(jobs);
    final start = _weekStart(anchor);
    final days = [for (int i = 0; i < 7; i++) start.add(Duration(days: i))];
    final today = DateTime.now();

    if (Breakpoints.isMobile(context)) {
      return Column(
        children: [
          for (final day in days)
            _WeekDayRow(
              day: day,
              jobs: byDay[day] ?? const [],
              isToday: _sameDay(day, today),
            ),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: SpacingTokens.xs),
                child: _WeekDayColumn(
                  day: day,
                  jobs: byDay[day] ?? const [],
                  isToday: _sameDay(day, today),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.day,
    required this.jobs,
    required this.isToday,
  });

  final DateTime day;
  final List<ScheduledJob> jobs;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = [...jobs]..sort(_byScheduledTime);

    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(SpacingTokens.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday ? scheme.primary : theme.dividerColor,
        ),
        color: isToday ? scheme.primary.withOpacity(0.06) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _weekdayLabels[day.weekday - 1],
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            '${day.day}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isToday ? scheme.primary : null,
              fontWeight: isToday ? FontWeight.w700 : null,
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          for (final job in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _PostChip(
                job: job,
                onTap: () => _showDaySheet(context, day, sorted),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({
    required this.day,
    required this.jobs,
    required this.isToday,
  });

  final DateTime day;
  final List<ScheduledJob> jobs;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = [...jobs]..sort(_byScheduledTime);

    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday ? scheme.primary : theme.dividerColor,
        ),
        color: isToday ? scheme.primary.withOpacity(0.06) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Text(
                  _weekdayLabels[day.weekday - 1],
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  '${day.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isToday ? scheme.primary : null,
                    fontWeight: isToday ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: sorted.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Nothing scheduled',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final job in sorted)
                        _PostChip(
                          job: job,
                          onTap: () => _showDaySheet(context, day, sorted),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A single post as a compact chip: platform icon + time + platform, tinted in
/// the platform's brand colour.
class _PostChip extends StatelessWidget {
  const _PostChip({required this.job, this.onTap});

  final ScheduledJob job;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = PlatformStyle.color(job.platform, theme.colorScheme);
    final when = (job.scheduledAt ?? job.createdAt).toLocal();
    final time = '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PlatformStyle.icon(job.platform), size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$time - ${PlatformStyle.label(job.platform)}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder shown while the calendar's jobs load.
class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row() => Container(
          margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
          padding: const EdgeInsets.all(SpacingTokens.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Skeleton.circle(34),
              const SizedBox(width: SpacingTokens.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 120, height: 12),
                    SizedBox(height: 6),
                    Skeleton(width: 80, height: 10),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(children: [for (var i = 0; i < 4; i++) row()]);
  }
}
