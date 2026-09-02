import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/platform_style.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../media_library/data/api_media_repository.dart';
import '../../../media_library/domain/media_item.dart';
import '../../../scheduler/presentation/state/scheduler_controller.dart';
import '../../../social_accounts/domain/entities/social_platform.dart';
import '../../data/repositories/api_publish_repository.dart';
import '../../domain/entities/publish_models.dart';

/// Opens the carousel composer in a large, responsive dialog. Assembles a
/// multi-image "carousel" post from the media library and publishes/schedules
/// it via POST /publish/carousel. Reuses existing data (media library + the
/// publish feature's connected-account targets); builds no new backend
/// concepts.
///
/// A large, centred dialog (not a bottom sheet) so the composer is spacious:
/// the title and the action bar stay pinned, and the sections sit in a roomy
/// scroll area between them — on desktop everything fits without scrolling.
/// The dialog fills most of the screen on mobile.
Future<void> showCarouselComposer(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _CarouselComposer(),
  );
}

/// Connected accounts as carousel destinations — reuses the publish feature's
/// `/social-accounts` targets (no dependency on the accounts controller, which
/// is web-only).
final _carouselTargetsProvider =
    FutureProvider.autoDispose<List<PublishTarget>>((ref) async {
  return ref.watch(publishRepositoryProvider).targets();
});

/// Per-platform ceiling on carousel items. Mirrors each adapter's
/// capabilities().maxCarouselItems on the backend, which stays authoritative —
/// this is only for friendly client-side hints and disabling.
int _maxItemsFor(SocialPlatform p) => switch (p) {
      SocialPlatform.instagram => 10,
      SocialPlatform.threads => 20,
      SocialPlatform.facebook => 10,
      SocialPlatform.x => 4,
      SocialPlatform.linkedin => 20,
    };

int _maxItemsForApi(String apiValue) =>
    _maxItemsFor(SocialPlatformX.fromApiValue(apiValue));

class _CarouselComposer extends ConsumerStatefulWidget {
  const _CarouselComposer();

  @override
  ConsumerState<_CarouselComposer> createState() => _CarouselComposerState();
}

class _CarouselComposerState extends ConsumerState<_CarouselComposer> {
  final _caption = TextEditingController();
  final _hashtags = TextEditingController();
  final _selected = <MediaItem>[]; // selection order IS the carousel order
  // Destinations — the same carousel is published to every selected account,
  // so more than one platform can be chosen at once.
  final _accounts = <PublishTarget>[];
  DateTime? _scheduledAt; // null = publish now
  bool _submitting = false;

  @override
  void dispose() {
    _caption.dispose();
    _hashtags.dispose();
    super.dispose();
  }

  /// Caption + hashtags combined into the single text the platforms accept:
  /// the caption, then the normalised hashtags on their own line. Null when
  /// both are empty.
  String? _composeCaption() {
    final caption = _caption.text.trim();
    final tags = _normalizedHashtags();
    final parts = [
      if (caption.isNotEmpty) caption,
      if (tags.isNotEmpty) tags,
    ];
    return parts.isEmpty ? null : parts.join('\n\n');
  }

  /// Splits the hashtags field on spaces/commas, prefixes each with a single
  /// '#', and de-duplicates (case-insensitively) while keeping order.
  String _normalizedHashtags() {
    final tokens = _hashtags.text
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

  /// The strictest item ceiling across the chosen platforms — the same image
  /// set goes to all of them, so it must satisfy the smallest limit.
  int get _maxItems {
    if (_accounts.isEmpty) return 20;
    return _accounts
        .map((a) => _maxItemsForApi(a.platform))
        .reduce((a, b) => a < b ? a : b);
  }

  /// Label of the platform imposing that strictest ceiling, for the hint.
  String? get _strictestLabel {
    if (_accounts.isEmpty) return null;
    final strictest = _accounts.reduce(
      (a, b) =>
          _maxItemsForApi(a.platform) <= _maxItemsForApi(b.platform) ? a : b,
    );
    return PlatformStyle.label(strictest.platform);
  }

  bool get _canSubmit => _disabledReason == null && !_submitting;

  /// Why Publish/Schedule is currently unavailable, or null when it's ready.
  /// Surfaced inline so the (theme-tinted) button never looks clickable
  /// without saying what's missing.
  String? get _disabledReason {
    if (_accounts.isEmpty) return 'Choose at least one account to publish to.';
    if (_selected.isEmpty) {
      return 'Tap at least 1 image above to include it.';
    }
    if (_selected.length > _maxItems) {
      return '$_strictestLabel allows at most '
          '$_maxItems images — remove ${_selected.length - _maxItems}.';
    }
    if (_scheduledAt != null && !_scheduledAt!.isAfter(DateTime.now())) {
      return 'Pick a time in the future.';
    }
    return null;
  }

  /// Adds/removes a destination account, trimming any images that now exceed
  /// the (possibly stricter) combined ceiling.
  void _toggleAccount(PublishTarget account) {
    setState(() {
      final i = _accounts.indexWhere((x) => x.id == account.id);
      if (i >= 0) {
        _accounts.removeAt(i);
      } else {
        _accounts.add(account);
      }
      if (_selected.length > _maxItems) {
        _selected.removeRange(_maxItems, _selected.length);
      }
    });
  }

  void _toggle(MediaItem item) {
    setState(() {
      final i = _selected.indexWhere((m) => m.id == item.id);
      if (i >= 0) {
        _selected.removeAt(i);
      } else {
        _selected.add(item);
      }
    });
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final messenger = ScaffoldMessenger.of(context);
    final scheduled = _scheduledAt != null;
    final targets = List<PublishTarget>.from(_accounts);
    final mediaUrls = _selected.map((m) => m.url).toList();
    final caption = _composeCaption();
    setState(() => _submitting = true);

    // The same carousel goes to each chosen account as its own queued job, so
    // one platform failing doesn't cancel the others.
    final failures = <String>[];
    for (final target in targets) {
      try {
        await ref.read(publishRepositoryProvider).publishCarousel(
              socialAccountId: target.id,
              mediaUrls: mediaUrls,
              caption: caption,
              scheduledAt: _scheduledAt,
            );
      } catch (error) {
        failures.add(
          '${PlatformStyle.label(target.platform)}: ${describeApiError(error)}',
        );
      }
    }
    if (!mounted) return;
    // Refresh the calendar so the new jobs show up there.
    ref.invalidate(schedulerJobsProvider);

    if (failures.isEmpty) {
      final names =
          targets.map((t) => PlatformStyle.label(t.platform)).join(', ');
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            scheduled
                ? 'Carousel scheduled for $names.'
                : 'Carousel queued to $names. Track it on the Calendar.',
          ),
        ),
      );
    } else {
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
            content: Text('Some publishes failed — ${failures.join('; ')}'),),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = ref.watch(mediaLibraryProvider);
    final accounts = ref.watch(_carouselTargetsProvider);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 720;

    return Dialog(
      insetPadding:
          EdgeInsets.all(isWide ? SpacingTokens.xl : SpacingTokens.sm),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: size.height * (isWide ? 0.9 : 0.96),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.xl,
            SpacingTokens.lg,
            SpacingTokens.xl,
            SpacingTokens.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (title + close) stays pinned above the scroll.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Post',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: SpacingTokens.xs),
                        Text(
                          'Pick one or more images and publish them as a carousel.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.lg),
              // Scrollable body — spacious inside the tall dialog, so on
              // desktop everything fits without scrolling.
              Expanded(
                child: ListView(
                  children: [
                    // --- Destination account ---------------------------------------
                    Text('Publish to', style: theme.textTheme.titleSmall),
                    const SizedBox(height: SpacingTokens.sm),
                    accounts.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(
                        'Could not load accounts: ${describeApiError(e)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      data: (list) {
                        final connected =
                            list.where((a) => a.isConnected).toList();
                        if (connected.isEmpty) {
                          return Text(
                            'Connect a social account in Settings first.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,),
                          );
                        }
                        return Wrap(
                          spacing: SpacingTokens.sm,
                          runSpacing: SpacingTokens.xs,
                          children: [
                            for (final a in connected)
                              FilterChip(
                                selected: _accounts.any((x) => x.id == a.id),
                                avatar: Icon(
                                  PlatformStyle.icon(a.platform),
                                  size: 16,
                                  color: PlatformStyle.color(
                                      a.platform, theme.colorScheme,),
                                ),
                                label: Text(PlatformStyle.label(a.platform)),
                                onSelected: (_) => _toggleAccount(a),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: SpacingTokens.lg),

                    // --- Image picker ----------------------------------------------
                    Row(
                      children: [
                        Expanded(
                          child:
                              Text('Images', style: theme.textTheme.titleSmall),
                        ),
                        Text(
                          '${_selected.length} selected'
                          '${_accounts.isNotEmpty ? ' · max $_maxItems' : ''}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _selected.length > _maxItems
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SpacingTokens.sm),
                    media.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(SpacingTokens.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(
                        'Could not load media: ${describeApiError(e)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      data: (items) {
                        final images = items.where((m) => !m.isVideo).toList();
                        if (images.isEmpty) {
                          return Text(
                            'Upload at least 1 image to the media library first.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,),
                          );
                        }
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 120,
                            mainAxisSpacing: SpacingTokens.sm,
                            crossAxisSpacing: SpacingTokens.sm,
                            childAspectRatio: 1,
                          ),
                          itemCount: images.length,
                          itemBuilder: (context, i) => _SelectableTile(
                            key: ValueKey('carousel-tile-${images[i].id}'),
                            item: images[i],
                            order: _selected
                                .indexWhere((m) => m.id == images[i].id),
                            onTap: () => _toggle(images[i]),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: SpacingTokens.lg),

                    // --- Caption ----------------------------------------------------
                    TextField(
                      controller: _caption,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Caption (optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.md),

                    // --- Hashtags ---------------------------------------------------
                    TextField(
                      controller: _hashtags,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Hashtags (optional)',
                        hintText: '#marketing #launch #socialmedia',
                        helperText:
                            'Separate with spaces or commas — added below the caption.',
                        prefixIcon: Icon(Icons.tag),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.md),

                    // --- Schedule ---------------------------------------------------
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Schedule for later'),
                      subtitle: _scheduledAt == null
                          ? const Text('Off — publishes now')
                          : Text('Scheduled for ${_formatWhen(_scheduledAt!)}'),
                      value: _scheduledAt != null,
                      onChanged: (on) async {
                        if (on) {
                          await _pickSchedule();
                        } else {
                          setState(() => _scheduledAt = null);
                        }
                      },
                    ),
                    if (_scheduledAt != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _pickSchedule,
                          icon: const Icon(Icons.edit_calendar_outlined,
                              size: 18,),
                          label: const Text('Change time'),
                        ),
                      ),
                    const SizedBox(height: SpacingTokens.sm),
                  ],
                ),
              ),
              // Inline reason the action is unavailable — pinned above the
              // action bar so it's always visible without scrolling.
              if (!_submitting && _disabledReason != null) ...[
                const SizedBox(height: SpacingTokens.md),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    Expanded(
                      child: Text(
                        _disabledReason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: SpacingTokens.md),
              // --- Actions (pinned footer) ---------------------------------
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_scheduledAt == null ? 'Publish' : 'Schedule'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    super.key,
    required this.item,
    required this.order,
    required this.onTap,
  });

  final MediaItem item;

  /// Position in the carousel (0-based), or -1 when not selected.
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = order >= 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
          if (selected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
                color: theme.colorScheme.primary.withOpacity(0.15),
              ),
            ),
          // Corner indicator: a numbered badge when selected, an empty circle
          // when not — so the tile clearly reads as tappable/selectable.
          Positioned(
            top: 4,
            right: 4,
            child: selected
                ? CircleAvatar(
                    radius: 11,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      '${order + 1}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onPrimary),
                    ),
                  )
                : Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.35),
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _formatWhen(DateTime dt) {
  const months = [
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
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month - 1]} at ${dt.hour}:$mm';
}
