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

/// Opens the carousel composer in a bottom sheet. Assembles a multi-image
/// "carousel" post from the media library and publishes/schedules it via
/// POST /publish/carousel. Reuses existing data (media library + the publish
/// feature's connected-account targets); builds no new backend concepts.
Future<void> showCarouselComposer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
  final _selected = <MediaItem>[]; // selection order IS the carousel order
  PublishTarget? _account;
  DateTime? _scheduledAt; // null = publish now
  bool _submitting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  int get _maxItems =>
      _account == null ? 20 : _maxItemsForApi(_account!.platform);

  bool get _canSubmit => _disabledReason == null && !_submitting;

  /// Why Publish/Schedule is currently unavailable, or null when it's ready.
  /// Surfaced inline so the (theme-tinted) button never looks clickable
  /// without saying what's missing.
  String? get _disabledReason {
    if (_account == null) return 'Choose an account to publish to.';
    if (_selected.length < 2) {
      return 'Tap at least 2 images above to include them'
          '${_selected.length == 1 ? ' (1 selected)' : ''}.';
    }
    if (_selected.length > _maxItems) {
      return '${PlatformStyle.label(_account!.platform)} allows at most '
          '$_maxItems images — remove ${_selected.length - _maxItems}.';
    }
    if (_scheduledAt != null && !_scheduledAt!.isAfter(DateTime.now())) {
      return 'Pick a time in the future.';
    }
    return null;
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
    final label = PlatformStyle.label(_account!.platform);
    final scheduled = _scheduledAt != null;
    setState(() => _submitting = true);
    try {
      await ref.read(publishRepositoryProvider).publishCarousel(
            socialAccountId: _account!.id,
            mediaUrls: _selected.map((m) => m.url).toList(),
            caption: _caption.text.isEmpty ? null : _caption.text,
            scheduledAt: _scheduledAt,
          );
      if (!mounted) return;
      // Refresh the calendar so the new job shows up there.
      ref.invalidate(schedulerJobsProvider);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            scheduled
                ? 'Carousel scheduled for $label.'
                : 'Carousel queued to $label. Track it on the Calendar.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not publish: ${describeApiError(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = ref.watch(mediaLibraryProvider);
    final accounts = ref.watch(_carouselTargetsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.fromLTRB(
          SpacingTokens.lg,
          0,
          SpacingTokens.lg,
          SpacingTokens.lg + bottomInset,
        ),
        child: ListView(
          controller: controller,
          children: [
            Text('New carousel post', style: theme.textTheme.titleLarge),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              'Pick 2 or more images and publish them as one carousel.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: SpacingTokens.lg),

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
                final connected = list.where((a) => a.isConnected).toList();
                if (connected.isEmpty) {
                  return Text(
                    'Connect a social account in Settings first.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  );
                }
                return Wrap(
                  spacing: SpacingTokens.sm,
                  runSpacing: SpacingTokens.xs,
                  children: [
                    for (final a in connected)
                      ChoiceChip(
                        selected: _account?.id == a.id,
                        avatar: Icon(
                          PlatformStyle.icon(a.platform),
                          size: 16,
                          color:
                              PlatformStyle.color(a.platform, theme.colorScheme),
                        ),
                        label: Text(PlatformStyle.label(a.platform)),
                        onSelected: (_) => setState(() {
                          _account = a;
                          // Trim any overflow beyond the new platform's max.
                          final max = _maxItemsForApi(a.platform);
                          if (_selected.length > max) {
                            _selected.removeRange(max, _selected.length);
                          }
                        }),
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
                  child: Text('Images', style: theme.textTheme.titleSmall),
                ),
                Text(
                  '${_selected.length} selected'
                  '${_account != null ? ' · max $_maxItems' : ''}',
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
                if (images.length < 2) {
                  return Text(
                    'Upload at least 2 images to the media library first.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                    order: _selected.indexWhere((m) => m.id == images[i].id),
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
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text('Change time'),
                ),
              ),
            const SizedBox(height: SpacingTokens.lg),

            // Inline reason the action is unavailable — the themed button stays
            // tinted even when disabled, so say what's missing.
            if (!_submitting && _disabledReason != null) ...[
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
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.sm),
            ],

            // --- Actions ----------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month - 1]} at ${dt.hour}:$mm';
}
