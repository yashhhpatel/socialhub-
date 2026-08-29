import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/skeleton.dart';
import '../../../../core/motion/tap_scale.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../publish/presentation/widgets/carousel_composer.dart';
import '../../data/api_media_repository.dart';
import '../../data/file_picker.dart';
import '../../domain/media_item.dart';

/// Library filter by media kind.
enum _MediaFilter { all, images, videos }

/// Media library — upload images/videos and get a hosted URL to reuse in a
/// design, brand kit logo, or white-label branding.
///
/// Uploads persist to the org's library (a server-side `MediaAsset`), so the
/// catalogue is the same every time you return — not just this session.
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  bool _uploading = false;
  final _search = TextEditingController();
  String _query = '';
  _MediaFilter _filter = _MediaFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Applies the active search + kind filter to the loaded library.
  List<MediaItem> _visible(List<MediaItem> items) {
    final q = _query.trim().toLowerCase();
    return items.where((m) {
      final matchesKind = switch (_filter) {
        _MediaFilter.all => true,
        _MediaFilter.images => !m.isVideo,
        _MediaFilter.videos => m.isVideo,
      };
      final matchesQuery = q.isEmpty || m.name.toLowerCase().contains(q);
      return matchesKind && matchesQuery;
    }).toList();
  }

  Future<void> _pickAndUpload() async {
    // Uploading needs an account (it hits an authenticated endpoint). Keep the
    // Upload button clickable while logged out, but route to login on click —
    // don't open the file picker — matching Marketplace Search's gating.
    if (ref.read(authTokenStoreProvider) == null) {
      final from = GoRouterState.of(context).uri.toString();
      context.go('/login?from=${Uri.encodeComponent(from)}');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ref.read(filePickerProvider)();
      if (picked == null) return; // cancelled
      setState(() => _uploading = true);
      await ref.read(mediaRepositoryProvider).upload(
            bytes: picked.bytes,
            name: picked.name,
            mimeType: picked.mimeType,
          );
      // Refresh the persisted list so the new upload appears.
      ref.invalidate(mediaLibraryProvider);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Upload failed: ${describeApiError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(MediaItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(mediaRepositoryProvider).delete(item.id);
      ref.invalidate(mediaLibraryProvider);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: ${describeApiError(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loggedIn = ref.watch(authTokenStoreProvider) != null;
    final library = ref.watch(mediaLibraryProvider);

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
                    Text('Media Library',
                        style: theme.textTheme.headlineMedium,),
                    const SizedBox(height: SpacingTokens.xs),
                    Text(
                      'Upload images and videos and reuse their hosted URLs anywhere.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (loggedIn) ...[
                OutlinedButton.icon(
                  onPressed: () => showCarouselComposer(context),
                  icon: const Icon(Icons.collections_outlined),
                  label: const Text('New carousel'),
                ),
                const SizedBox(width: SpacingTokens.sm),
              ],
              FilledButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: const Text('Upload'),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          if (!loggedIn)
            const _Empty()
          else
            library.when(
              loading: () => const _MediaSkeletonGrid(),
              error: (error, _) => _LoadError(message: describeApiError(error)),
              data: (items) {
                if (items.isEmpty) return const _Empty();
                final visible = _visible(items);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Controls(
                      controller: _search,
                      filter: _filter,
                      total: items.length,
                      shown: visible.length,
                      onQuery: (q) => setState(() => _query = q),
                      onFilter: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: SpacingTokens.md),
                    if (visible.isEmpty)
                      const _NoMatches()
                    else
                      _Grid(items: visible, onDelete: _delete),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Search + kind filter, with a live "showing N of M" count. Wraps on mobile.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.filter,
    required this.total,
    required this.shown,
    required this.onQuery,
    required this.onFilter,
  });

  final TextEditingController controller;
  final _MediaFilter filter;
  final int total;
  final int shown;
  final ValueChanged<String> onQuery;
  final ValueChanged<_MediaFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: SpacingTokens.md,
          runSpacing: SpacingTokens.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: controller,
                onChanged: onQuery,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search by name',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            controller.clear();
                            onQuery('');
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SegmentedButton<_MediaFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _MediaFilter.all, label: Text('All')),
                ButtonSegment(
                    value: _MediaFilter.images, label: Text('Images'),),
                ButtonSegment(
                    value: _MediaFilter.videos, label: Text('Videos'),),
              ],
              selected: {filter},
              onSelectionChanged: (s) => onFilter(s.first),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.xs),
        Text(
          'Showing $shown of $total',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Shimmer placeholder grid shown while the library loads.
class _MediaSkeletonGrid extends StatelessWidget {
  const _MediaSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: SpacingTokens.md,
        crossAxisSpacing: SpacingTokens.md,
        childAspectRatio: 0.82,
      ),
      itemCount: 8,
      itemBuilder: (context, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Skeleton(
                  height: double.infinity, borderRadius: BorderRadius.zero,),
            ),
            Padding(
              padding: EdgeInsets.all(SpacingTokens.sm),
              child: Skeleton(width: 120, height: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// No results for the active search/filter (the library itself isn't empty).
class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined,
                size: 36, color: theme.colorScheme.onSurfaceVariant,),
            const SizedBox(height: SpacingTokens.sm),
            Text('No media matches your search',
                style: theme.textTheme.titleMedium,),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.onDelete});

  final List<MediaItem> items;
  final void Function(MediaItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 240,
        crossAxisSpacing: SpacingTokens.md,
        mainAxisSpacing: SpacingTokens.md,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) =>
          _MediaCard(media: items[i], onDelete: onDelete),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.media, required this.onDelete});

  final MediaItem media;
  final void Function(MediaItem) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TapScale(
      hoverElevation: true,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: media.isVideo
                        ? (media.posterUrl != null
                            ? Image.network(
                                media.posterUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child:
                                      Icon(Icons.videocam_outlined, size: 32),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.videocam_outlined, size: 32),
                              ))
                        : Image.network(
                            media.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_outlined),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _TypeBadge(isVideo: media.isVideo),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      media.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy URL',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: media.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied.')),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    onPressed: () => onDelete(media),
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

/// Small pill over a thumbnail marking whether it's an image or a video.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isVideo});
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.videocam_outlined : Icons.image_outlined,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isVideo ? 'Video' : 'Image',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
          const SizedBox(height: SpacingTokens.md),
          Text("Couldn't load your media", style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(message,
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center,),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.perm_media_outlined,
              size: 40, color: theme.colorScheme.onSurfaceVariant,),
          const SizedBox(height: SpacingTokens.md),
          Text('No uploads yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Upload an image or video to get a hosted URL you can reuse.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
