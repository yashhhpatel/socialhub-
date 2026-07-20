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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.layer, required this.selected, required this.onTap});

  final CanvasLayer layer;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (layer) {
        ImageCanvasLayer() => Icons.image_outlined,
        TextCanvasLayer() => Icons.text_fields,
        ShapeCanvasLayer() => Icons.category_outlined,
      };

  String get _label => switch (layer) {
        ImageCanvasLayer() => 'Image',
        TextCanvasLayer(:final text) => text.isEmpty ? 'Text' : text,
        ShapeCanvasLayer(:final shapeKind) =>
          shapeKind == ShapeKind.ellipse ? 'Ellipse' : 'Rectangle',
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
                    color: selected ? colorScheme.primary : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
