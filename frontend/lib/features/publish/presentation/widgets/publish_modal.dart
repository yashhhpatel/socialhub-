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
  int? _selectedPairIndex;

  /// The caption that will actually be posted. Owned here rather than in
  /// CaptionPanel because the publish button needs to read it, and because
  /// it must survive the panel rebuilding as generation state changes.
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
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
              PublishPhase.succeeded => _PublishSucceeded(job: publish.job!),
              PublishPhase.failed => _PublishFailed(
                  error: publish.error ?? 'Publish failed.',
                  onRetry: () => ref.read(publishControllerProvider.notifier).reset(),
                ),
              _ => options.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(describeApiError(e))),
                  data: (data) => _PairPicker(
                    options: data,
                    selectedIndex: _selectedPairIndex,
                    onSelect: (i) => setState(() {
                      _selectedPairIndex = i;
                      // Seed from the variant's stored caption, but never
                      // over text the user has already generated or typed.
                      final existing = data.publishablePairs[i].variant.caption;
                      if (_captionController.text.isEmpty && existing != null) {
                        _captionController.text = existing;
                      }
                    }),
                  ),
                ),
            },
          ),
          if (publish.phase == PublishPhase.idle ||
              publish.phase == PublishPhase.publishing) ...[
            options.maybeWhen(
              data: (data) {
                final pairs = data.publishablePairs;
                // Index can outlive the list it pointed into if options
                // refetch while the modal is open.
                final selected = _selectedPairIndex != null &&
                        _selectedPairIndex! < pairs.length
                    ? pairs[_selectedPairIndex!]
                    : null;

                // Only after a destination is chosen: the caption's length
                // limit is the platform's, so there is nothing meaningful
                // to show a counter against until one is picked.
                if (selected == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: SpacingTokens.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CaptionPanel(
                        assetId: widget.assetId,
                        textController: _captionController,
                        maxLength: selected.variant.maxCaptionLength,
                        enabled: !publish.inFlight,
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
                final pairs = data.publishablePairs;
                final canPublish = _selectedPairIndex != null &&
                    _selectedPairIndex! < pairs.length &&
                    !publish.inFlight;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: canPublish
                          ? () => _scheduleSelected(pairs[_selectedPairIndex!])
                          : null,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: const Text('Schedule'),
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    FilledButton.icon(
                      onPressed: canPublish
                          ? () {
                              final pair = pairs[_selectedPairIndex!];
                              ref.read(publishControllerProvider.notifier).publish(
                                    variantId: pair.variant.id,
                                    socialAccountId: pair.target.id,
                                    caption: _captionArg(pair),
                                  );
                            }
                          : null,
                      icon: publish.inFlight
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: Text(publish.inFlight ? 'Publishing…' : 'Publish now'),
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

  /// Untouched field => null (the variant's own caption still applies);
  /// deliberately cleared => '' (the backend honours that as "no caption").
  String? _captionArg(({PublishableVariant variant, PublishTarget target}) pair) {
    final caption = _captionController.text;
    return caption.isEmpty && pair.variant.caption == null ? null : caption;
  }

  /// Picks a future date + time and schedules the selected pair (Milestone
  /// 7.4). The caption is resolved the same way an immediate publish does.
  Future<void> _scheduleSelected(
    ({PublishableVariant variant, PublishTarget target}) pair,
  ) async {
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

    try {
      await ref.read(schedulerRepositoryProvider).schedule(
            variantId: pair.variant.id,
            socialAccountId: pair.target.id,
            scheduledAt: scheduledAt,
            caption: _captionArg(pair),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post scheduled. See it on your calendar.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule: ${describeApiError(error)}')),
      );
    }
  }
}

class _PairPicker extends StatelessWidget {
  const _PairPicker({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  final PublishOptions options;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

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
        final selected = selectedIndex == index;
        return InkWell(
          onTap: () => onSelect(index),
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
                if (selected) Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PublishSucceeded extends StatelessWidget {
  const _PublishSucceeded({required this.job});

  final PublishJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: SpacingTokens.md),
          Text('Published', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          if (job.externalPostId != null)
            Text('Post id: ${job.externalPostId}', style: theme.textTheme.bodySmall),
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
