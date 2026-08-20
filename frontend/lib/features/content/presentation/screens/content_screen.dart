import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion_switcher.dart';
import '../../../../core/motion/skeleton.dart';
import '../../../../core/motion/staggered_item.dart';
import '../../../../core/motion/tap_scale.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../../core/widgets/sign_in_required.dart';
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
                    Text('Content', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: SpacingTokens.xs),
                    Text(
                      'Create once, then publish everywhere.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
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
            ],
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
              error: (error, _) => KeyedSubtree(
                key: const ValueKey('error'),
                child: isUnauthorized(error)
                    ? const SignInRequired(
                        message: 'Log in to view and create designs.',
                      )
                    : _LibraryError(
                        message: describeApiError(error),
                        onRetry: () => ref.invalidate(contentLibraryProvider),
                      ),
              ),
              data: (assets) => KeyedSubtree(
                key: const ValueKey('data'),
                child: assets.isEmpty
                    ? const _EmptyLibrary()
                    : _AssetGrid(assets: assets),
              ),
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
  const _AssetGrid({required this.assets});

  final List<ContentAssetSummary> assets;

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
        child: _AssetCard(asset: assets[index]),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset});

  final ContentAssetSummary asset;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Design ${asset.id.substring(0, 8)}',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asset.variantCount > 0
                          ? '${asset.variantCount} platform variant'
                              '${asset.variantCount == 1 ? '' : 's'}'
                          : asset.approvalStatus,
                      style: theme.textTheme.labelSmall,
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
