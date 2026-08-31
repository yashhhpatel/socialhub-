import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion_switcher.dart';
import '../../../../core/motion/skeleton.dart';
import '../../../../core/motion/staggered_item.dart';
import '../../../../core/motion/tap_scale.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/layout/widgets/page_header.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_content_repository.dart';
import '../../domain/entities/content_asset_summary.dart';
import '../state/content_library_controller.dart';

/// The content library — the entry point into the editor (Milestone 3.6).
///
/// Replaces the ComingSoonPlaceholder that stood here since Milestone
/// 0.2. Until now the canvas engine (3.3), panels (3.4) and undo/redo +
/// autosave (3.5) were all built but unreachable: nothing in the app
/// routed to EditorScreen, so none of that work was usable or even
/// visible in the running product. This screen is the door.
class ContentScreen extends ConsumerStatefulWidget {
  const ContentScreen({super.key});

  @override
  ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen> {
  bool _creating = false;

  /// Deletes in flight — used to disable the card's delete button and block a
  /// second request for the same design (fixes double-click).
  final Set<String> _deletingIds = {};

  /// Successfully deleted — filtered out of the grid so the design disappears
  /// instantly, with no list refetch/flicker and no page refresh.
  final Set<String> _deletedIds = {};

  /// Confirms, then deletes a design. The confirmation dialog is fully resolved
  /// (closed) BEFORE any async work runs, so its modal barrier can never be
  /// left covering the app if the delete throws — that barrier-stuck-up case is
  /// the classic "whole app frozen until refresh" bug. All state is reset in
  /// every path; on failure the design stays visible and interactive.
  Future<void> _confirmAndDelete(ContentAssetSummary asset) async {
    // Guard against a duplicate request for the same design (double-click).
    if (_deletingIds.contains(asset.id)) return;

    final name = _designName(asset);
    // useRootNavigator + rootNavigator on the pops are explicit (not defaults)
    // so the dialog and its barrier are pushed to, and popped from, the SAME
    // (root) navigator. Under go_router's nested ShellRoute navigators, leaving
    // this implicit is how a barrier can end up on one navigator and the pop
    // target on another — stranding the barrier and freezing the whole app.
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete design?'),
        content:
            Text('"$name" will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // The dialog (and its barrier) is gone by here regardless of the choice.
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deletingIds.add(asset.id));
    try {
      await ref.read(contentRepositoryProvider).deleteAsset(asset.id);
      if (!mounted) return;
      setState(() {
        _deletingIds.remove(asset.id);
        _deletedIds.add(asset.id); // remove from the grid without a refetch
      });
      messenger.showSnackBar(SnackBar(content: Text('"$name" deleted.')));
    } catch (error) {
      if (!mounted) return;
      // Keep the design visible + interactive; just clear the busy state.
      setState(() => _deletingIds.remove(asset.id));
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: ${describeApiError(error)}')),
      );
    }
  }

  String _designName(ContentAssetSummary asset) =>
      'Design ${asset.id.substring(0, 8)}';

  Future<void> _createAndOpen() async {
    setState(() => _creating = true);
    try {
      final id = await createBlankAsset(ref);
      if (!mounted) return;
      context.go('/editor/$id');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create design: ${describeApiError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(contentLibraryProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Content',
            subtitle: 'Create once, then publish everywhere.',
            trailing: FilledButton.icon(
              onPressed: _creating ? null : _createAndOpen,
              icon: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('New design'),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          // Cross-fade skeleton → real content as the library loads (motion).
          MotionSwitcher(
            alignment: Alignment.topCenter,
            child: library.when(
              loading: () => const KeyedSubtree(
                key: ValueKey('loading'),
                child: _SkeletonGrid(),
              ),
              // Logged out: show the normal empty library (browsable) rather
              // than a wall — "New design" routes to login when tapped.
              error: (error, _) => KeyedSubtree(
                key: const ValueKey('error'),
                child: isUnauthorized(error)
                    ? const _EmptyLibrary()
                    : _LibraryError(
                        message: describeApiError(error),
                        onRetry: () => ref.invalidate(contentLibraryProvider),
                      ),
              ),
              data: (assets) {
                // Hide optimistically-deleted designs (removed instantly, no
                // refetch). Falls back to the empty state once the last one goes.
                final visible =
                    assets.where((a) => !_deletedIds.contains(a.id)).toList();
                return KeyedSubtree(
                  key: const ValueKey('data'),
                  child: visible.isEmpty
                      ? const _EmptyLibrary()
                      : _AssetGrid(
                          assets: visible,
                          deletingIds: _deletingIds,
                          onDelete: _confirmAndDelete,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholders shown while the library loads, matching the grid.
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: SpacingTokens.md,
        crossAxisSpacing: SpacingTokens.md,
        childAspectRatio: 0.85,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => Skeleton(
        height: double.infinity,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({
    required this.assets,
    required this.deletingIds,
    required this.onDelete,
  });

  final List<ContentAssetSummary> assets;
  final Set<String> deletingIds;
  final void Function(ContentAssetSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: SpacingTokens.md,
        crossAxisSpacing: SpacingTokens.md,
        childAspectRatio: 0.85,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) => StaggeredItem(
        index: index,
        child: _AssetCard(
          asset: assets[index],
          isDeleting: deletingIds.contains(assets[index].id),
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.isDeleting,
    required this.onDelete,
  });

  final ContentAssetSummary asset;
  final bool isDeleting;
  final void Function(ContentAssetSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TapScale(
      hoverElevation: true,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go('/editor/${asset.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: asset.masterImageUrl == null
                    // No export yet — the design exists but has never been
                    // rendered, so there is genuinely nothing to show.
                    ? Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Image.network(asset.masterImageUrl!, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(SpacingTokens.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Design ${asset.id.substring(0, 8)}',
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _StatusBadge(status: asset.approvalStatus),
                              if (asset.variantCount > 0) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${asset.variantCount} variant'
                                    '${asset.variantCount == 1 ? '' : 's'}',
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Its own onPressed claims the tap, so pressing it never
                    // opens the editor (the card's InkWell). Disabled while a
                    // delete for this design is already in flight.
                    isDeleting
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Delete',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => onDelete(asset),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.grid_view_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: SpacingTokens.md),
          Text('No designs yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Create your first design to get started.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load your designs: $message'),
          const SizedBox(height: SpacingTokens.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// A small colored pill for a design's approval status.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, String label) = switch (status) {
      'approved' => (AppColors.success, 'Approved'),
      'pending_approval' => (AppColors.warning, 'Pending'),
      'rejected' => (AppColors.error, 'Rejected'),
      _ => (theme.colorScheme.onSurfaceVariant, 'Draft'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
