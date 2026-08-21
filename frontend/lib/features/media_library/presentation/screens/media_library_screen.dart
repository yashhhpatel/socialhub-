import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_media_repository.dart';
import '../../data/file_picker.dart';
import '../../domain/media_item.dart';

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
                    Text('Media Library', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: SpacingTokens.xs),
                    Text(
                      'Upload images and videos and reuse their hosted URLs anywhere.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
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
              loading: () => const Padding(
                padding: EdgeInsets.only(top: SpacingTokens.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _LoadError(message: describeApiError(error)),
              data: (items) => items.isEmpty
                  ? const _Empty()
                  : _Grid(items: items, onDelete: _delete),
            ),
        ],
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
      itemBuilder: (context, i) => _MediaCard(media: items[i], onDelete: onDelete),
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
    return Card(
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
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: media.isVideo
                  ? (media.posterUrl != null
                      ? Image.network(
                          media.posterUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.videocam_outlined, size: 32)),
                        )
                      : const Center(child: Icon(Icons.videocam_outlined, size: 32)))
                  : Image.network(
                      media.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined)),
                    ),
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
          Text(message, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
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
          Icon(Icons.perm_media_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
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
