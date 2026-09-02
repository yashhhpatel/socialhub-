import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/motion_modal.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../ai_suite/presentation/widgets/ai_tools_panel.dart';
import '../../../scheduler/data/repositories/api_scheduler_repository.dart';
import '../../domain/entities/publish_models.dart';
import '../state/caption_controller.dart';
import '../state/publish_controller.dart';
import 'caption_panel.dart';

/// Publish modal (Milestone 4.3) — pick a rendition + destination, see a
/// preview of exactly what will be posted, publish, and watch the result.
///
/// Shows the real rendered variant image rather than the editor canvas:
/// the whole point of per-platform variants is that Instagram gets 1:1
/// and X gets 16:9, so a preview of the un-cropped design would hide the
/// one thing the user most needs to check before posting publicly.
Future<void> showPublishModal(BuildContext context, String assetId) {
  // Scale-in + fade entrance (motion layer) instead of a hard appear.
  return showMotionModal<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: _PublishModal(assetId: assetId),
      ),
    ),
  );
}

class _PublishModal extends ConsumerStatefulWidget {
  const _PublishModal({required this.assetId});

  final String assetId;

  @override
  ConsumerState<_PublishModal> createState() => _PublishModalState();
}

class _PublishModalState extends ConsumerState<_PublishModal> {
  /// Indices into `publishablePairs` the user has selected. A Set (not a single
  /// index) so the same design can be published to several accounts at once.
  final Set<int> _selectedIndices = {};

  /// The caption that will actually be posted. Owned here rather than in
  /// CaptionPanel because the publish button needs to read it, and because
  /// it must survive the panel rebuilding as generation state changes.
  final _captionController = TextEditingController();

  /// Optional hashtags, appended below the caption at publish time.
  final _hashtagsController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  /// Caption + hashtags as the single text the platforms accept: the caption,
  /// then the normalised hashtags on their own line.
  String _composedCaption() {
    final caption = _captionController.text.trim();
    final tags = _normalizedHashtags();
    final parts = [
      if (caption.isNotEmpty) caption,
      if (tags.isNotEmpty) tags,
    ];
    return parts.join('\n\n');
  }

  /// Splits the hashtags field on spaces/commas, prefixes each with a single
  /// '#', and de-duplicates (case-insensitively) while keeping order.
  String _normalizedHashtags() {
    final tokens = _hashtagsController.text
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.trim().isNotEmpty);
    final seen = <String>{};
    final out = <String>[];
    for (final token in tokens) {
      final bare = token.replaceAll('#', '');
      if (bare.isEmpty) continue;
      final tag = '#$bare';
      if (seen.add(tag.toLowerCase())) out.add(tag);
    }
    return out.join(' ');
  }

  /// Toggles one account in/out of the selection, seeding the caption from the
  /// first one picked (but never over text the user has already typed).
  void _toggle(int index, PublishOptions data) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
        final existing = data.publishablePairs[index].variant.caption;
        if (_captionController.text.isEmpty && existing != null) {
          _captionController.text = existing;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(publishOptionsProvider(widget.assetId));
    final publish = ref.watch(publishControllerProvider);
    final theme = Theme.of(context);

    // A finished generation overwrites the field — that is what the user
    // asked for by pressing Generate. Done via listen rather than in the
    // panel's build so it fires once per generation, not on every rebuild
    // (which would fight the user's cursor while they type).
    ref.listen<CaptionState>(captionControllerProvider, (previous, next) {
      if (next.phase == CaptionPhase.ready &&
          next.caption != null &&
          next.caption != previous?.caption) {
        _captionController.text = next.caption!;
      }
    });

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text('Publish', style: theme.textTheme.headlineSmall)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: publish.inFlight ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Flexible(
            child: switch (publish.phase) {
              PublishPhase.succeeded =>
                _PublishSucceeded(job: publish.job, count: publish.successCount),
              PublishPhase.failed => _PublishFailed(
                  error: publish.error ?? 'Publish failed.',
                  onRetry: () => ref.read(publishControllerProvider.notifier).reset(),
                ),
              _ => options.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(describeApiError(e))),
                  data: (data) => _PairPicker(
                    options: data,
                    selectedIndices: _selectedIndices,
                    onToggle: (i) => _toggle(i, data),
                  ),
                ),
            },
          ),
          if (publish.phase == PublishPhase.idle ||
              publish.phase == PublishPhase.publishing) ...[
            options.maybeWhen(
              data: (data) {
                final selected = _selectedPairs(data);
                // Only after at least one destination is chosen: the caption's
                // length limit is the platform's, so there is nothing to show
                // a counter against until one is picked.
                if (selected.isEmpty) return const SizedBox.shrink();

                // Multiple platforms share the one caption, so hold it to the
                // strictest limit among the chosen ones.
                final maxLength = selected
                    .map((p) => p.variant.maxCaptionLength)
                    .reduce((a, b) => a < b ? a : b);

                return Padding(
                  padding: const EdgeInsets.only(top: SpacingTokens.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CaptionPanel(
                        assetId: widget.assetId,
                        textController: _captionController,
                        maxLength: maxLength,
                        enabled: !publish.inFlight,
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      // Separate hashtags field — appended below the caption.
                      TextField(
                        controller: _hashtagsController,
                        enabled: !publish.inFlight,
                        minLines: 1,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Hashtags (optional)',
                          hintText: '#marketing #launch',
                          helperText: 'Separate with spaces or commas — '
                              'added below the caption.',
                          prefixIcon: Icon(Icons.tag),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      AiToolsPanel(
                        assetId: widget.assetId,
                        captionController: _captionController,
                        enabled: !publish.inFlight,
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: SpacingTokens.md),
            options.maybeWhen(
              data: (data) {
                final selected = _selectedPairs(data);
                final canPublish = selected.isNotEmpty && !publish.inFlight;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: canPublish
                          ? () => _scheduleSelected(selected)
                          : null,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: const Text('Schedule'),
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    FilledButton.icon(
                      onPressed: canPublish
                          ? () => ref
                              .read(publishControllerProvider.notifier)
                              .publishMany([
                                for (final pair in selected)
                                  (
                                    variantId: pair.variant.id,
                                    socialAccountId: pair.target.id,
                                    caption: _captionArg(pair),
                                    label: pair.variant.platform,
                                  ),
                              ])
                          : null,
                      icon: publish.inFlight
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: Text(
                        publish.inFlight
                            ? 'Publishing…'
                            : selected.length > 1
                                ? 'Publish to ${selected.length}'
                                : 'Publish now',
                      ),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  /// The currently-selected pairs, dropping any index that has fallen out of
  /// range (the options list can refetch while the modal is open).
  List<({PublishableVariant variant, PublishTarget target})> _selectedPairs(
    PublishOptions data,
  ) {
    final pairs = data.publishablePairs;
    return [
      for (final i in _selectedIndices)
        if (i < pairs.length) pairs[i],
    ];
  }

  /// Untouched field => null (the variant's own caption still applies);
  /// deliberately cleared => '' (the backend honours that as "no caption").
  String? _captionArg(({PublishableVariant variant, PublishTarget target}) pair) {
    final composed = _composedCaption();
    return composed.isEmpty && pair.variant.caption == null ? null : composed;
  }

  /// Picks one future date + time and schedules every selected pair for it
  /// (Milestone 7.4). The caption is resolved the same way an immediate
  /// publish does; one platform failing doesn't cancel the others.
  Future<void> _scheduleSelected(
    List<({PublishableVariant variant, PublishTarget target})> pairs,
  ) async {
    if (pairs.isEmpty) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(hours: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final scheduler = ref.read(schedulerRepositoryProvider);
    final failures = <String>[];
    for (final pair in pairs) {
      try {
        await scheduler.schedule(
          variantId: pair.variant.id,
          socialAccountId: pair.target.id,
          scheduledAt: scheduledAt,
          caption: _captionArg(pair),
        );
      } catch (error) {
        failures.add('${pair.variant.platform}: ${describeApiError(error)}');
      }
    }
    if (!mounted) return;
    if (failures.isEmpty) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pairs.length > 1
                ? 'Scheduled to ${pairs.length} accounts. See them on your calendar.'
                : 'Post scheduled. See it on your calendar.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Some did not schedule — ${failures.join('; ')}')),
      );
    }
  }
}

class _PairPicker extends StatelessWidget {
  const _PairPicker({
    required this.options,
    required this.selectedIndices,
    required this.onToggle,
  });

  final PublishOptions options;
  final Set<int> selectedIndices;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final pairs = options.publishablePairs;
    final theme = Theme.of(context);

    if (pairs.isEmpty) {
      // Be specific about WHICH precondition is missing — "nothing to
      // publish" leaves the user guessing between two very different
      // fixes.
      final hasReadyVariant = options.variants.any((v) => v.isReady);
      final hasConnectedAccount = options.targets.any((t) => t.isConnected);
      final reason = !hasReadyVariant
          ? 'This design has no platform variants yet. Export it, then use '
              '"Generate variants" in the editor.'
          : !hasConnectedAccount
              ? 'No connected accounts. Connect one under Settings first.'
              : 'Your variants and connected accounts are for different '
                  'platforms. Generate a variant for a platform you have '
                  'connected.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Text(reason, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: pairs.length,
      separatorBuilder: (_, __) => const SizedBox(height: SpacingTokens.sm),
      itemBuilder: (context, index) {
        final pair = pairs[index];
        final selected = selectedIndices.contains(index);
        return InkWell(
          onTap: () => onToggle(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? theme.colorScheme.primary : theme.dividerColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // A checkbox makes it obvious several accounts can be picked.
                Checkbox(
                  value: selected,
                  onChanged: (_) => onToggle(index),
                ),
                const SizedBox(width: SpacingTokens.xs),
                // The actual rendition that will be posted, at the
                // platform's own aspect ratio.
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    pair.variant.renderedMediaUrl!,
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 96,
                      height: 96,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pair.variant.platform, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'to ${pair.target.externalAccountId}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PublishSucceeded extends StatelessWidget {
  const _PublishSucceeded({required this.job, this.count = 1});

  final PublishJob? job;

  /// How many accounts the design was published to.
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: SpacingTokens.md),
          Text(
            count > 1 ? 'Published to $count accounts' : 'Published',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: SpacingTokens.xs),
          // A single publish can name the post; a multi-publish can't point at
          // one id, so it just confirms the count above.
          if (count == 1 && job?.externalPostId != null)
            Text('Post id: ${job!.externalPostId}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PublishFailed extends StatelessWidget {
  const _PublishFailed({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: theme.colorScheme.error),
            const SizedBox(height: SpacingTokens.md),
            Text('Publish failed', style: theme.textTheme.titleMedium),
            const SizedBox(height: SpacingTokens.sm),
            // The platform's own words — "caption too long", "media not
            // reachable" — are what tell the user what to change.
            Text(error, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: SpacingTokens.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
