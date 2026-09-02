import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens/spacing_tokens.dart';
import '../canvas/models/canvas_document.dart';
import '../canvas/models/canvas_layer.dart';
import '../canvas/state/canvas_controller.dart';

/// Lists every layer in the current document. Displayed TOP-of-list =
/// TOP-of-stack (reverse of CanvasDocument.layers' paint order — see
/// that class's doc comment), matching the convention every mainstream
/// design tool uses: what you see on top visually is what you see on
/// top of this list.
class LayerPanel extends ConsumerWidget {
  const LayerPanel({super.key, required this.document});

  final CanvasDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = canvasControllerProvider(document);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final reversedLayers = state.document.layers.reversed.toList();

    final selectedIndex =
        state.document.layers.indexWhere((l) => l.id == state.selectedLayerId);
    final hasSelection = selectedIndex >= 0;

    return Container(
      width: 220,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(SpacingTokens.md),
            child: Text('Layers', style: Theme.of(context).textTheme.headlineMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: reversedLayers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(SpacingTokens.md),
                    child: Text(
                      'No layers yet — use the toolbar to add one.',
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  )
                : ListView.builder(
                    itemCount: reversedLayers.length,
                    itemBuilder: (context, index) {
                      final layer = reversedLayers[index];
                      final selected = layer.id == state.selectedLayerId;

                      return _LayerRow(
                        layer: layer,
                        selected: selected,
                        onTap: () => controller.selectLayerById(layer.id),
                        onToggleHidden: () =>
                            controller.setLayerHidden(layer.id, !layer.hidden),
                        onToggleLocked: () =>
                            controller.setLayerLocked(layer.id, !layer.locked),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          _LayerActions(
            enabled: hasSelection,
            canBringForward:
                hasSelection && selectedIndex < state.document.layers.length - 1,
            canSendBackward: hasSelection && selectedIndex > 0,
            onBringForward: controller.bringSelectedForward,
            onSendBackward: controller.sendSelectedBackward,
            onBringToFront: controller.bringSelectedToFront,
            onSendToBack: controller.sendSelectedToBack,
            onDuplicate: controller.duplicateSelectedLayer,
            onDelete: controller.deleteSelectedLayer,
          ),
        ],
      ),
    );
  }
}

/// Action bar for the selected layer: reorder within the stack, duplicate,
/// or delete. Buttons disable when there's no selection (or a reorder isn't
/// possible), rather than silently no-opping.
class _LayerActions extends StatelessWidget {
  const _LayerActions({
    required this.enabled,
    required this.canBringForward,
    required this.canSendBackward,
    required this.onBringForward,
    required this.onSendBackward,
    required this.onBringToFront,
    required this.onSendToBack,
    required this.onDuplicate,
    required this.onDelete,
  });

  final bool enabled;
  final bool canBringForward;
  final bool canSendBackward;
  final VoidCallback onBringForward;
  final VoidCallback onSendBackward;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.xs,
        vertical: SpacingTokens.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Bring to front',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.vertical_align_top, size: 18),
            onPressed: canBringForward ? onBringToFront : null,
          ),
          IconButton(
            tooltip: 'Bring forward',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: canBringForward ? onBringForward : null,
          ),
          IconButton(
            tooltip: 'Send backward',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_downward, size: 18),
            onPressed: canSendBackward ? onSendBackward : null,
          ),
          IconButton(
            tooltip: 'Send to back',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.vertical_align_bottom, size: 18),
            onPressed: canSendBackward ? onSendToBack : null,
          ),
          IconButton(
            tooltip: 'Duplicate (Ctrl+D)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            onPressed: enabled ? onDuplicate : null,
          ),
          IconButton(
            tooltip: 'Delete (Del)',
            visualDensity: VisualDensity.compact,
            color: colorScheme.error,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: enabled ? onDelete : null,
          ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.layer,
    required this.selected,
    required this.onTap,
    required this.onToggleHidden,
    required this.onToggleLocked,
  });

  final CanvasLayer layer;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleHidden;
  final VoidCallback onToggleLocked;

  IconData get _icon => switch (layer) {
        ImageCanvasLayer() => Icons.image_outlined,
        TextCanvasLayer() => Icons.text_fields,
        ShapeCanvasLayer() => Icons.category_outlined,
        VideoCanvasLayer() => Icons.videocam_outlined,
      };

  String get _label => switch (layer) {
        ImageCanvasLayer() => 'Image',
        TextCanvasLayer(:final text) => text.isEmpty ? 'Text' : text,
        ShapeCanvasLayer(:final shapeKind) => switch (shapeKind) {
            ShapeKind.rectangle => 'Rectangle',
            ShapeKind.ellipse => 'Ellipse',
            ShapeKind.triangle => 'Triangle',
            ShapeKind.star => 'Star',
            ShapeKind.diamond => 'Diamond',
          },
        VideoCanvasLayer() => 'Video',
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colorScheme.primary.withOpacity(0.12) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.md,
            vertical: SpacingTokens.sm,
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 18,
                color: selected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Expanded(
                child: Text(
                  _label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: layer.hidden
                        ? colorScheme.onSurface.withOpacity(0.4)
                        : selected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              // Hide/show and lock/unlock, so a background can be parked while
              // editing on top.
              IconButton(
                tooltip: layer.hidden ? 'Show' : 'Hide',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                color: colorScheme.onSurface.withOpacity(0.6),
                icon: Icon(
                  layer.hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
                onPressed: onToggleHidden,
              ),
              IconButton(
                tooltip: layer.locked ? 'Unlock' : 'Lock',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                color: layer.locked
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.6),
                icon: Icon(
                  layer.locked ? Icons.lock_outline : Icons.lock_open_outlined,
                ),
                onPressed: onToggleLocked,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
