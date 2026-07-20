import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens/spacing_tokens.dart';
import '../canvas/models/canvas_document.dart';
import '../canvas/models/canvas_layer.dart';
import '../canvas/state/canvas_controller.dart';

/// SCOPE NOTE: add-layer actions only, per this milestone. Deliberately
/// NOT here yet: image upload (needs Milestone 3.2's Cloudinary endpoint
/// wired into a picker UI — a reasonable next increment, not this one),
/// undo/redo (Milestone 3.5), alignment/smart guides (later Phase 3
/// milestones per the blueprint's phase-level feature list).
class EditorToolbar extends ConsumerWidget implements PreferredSizeWidget {
  const EditorToolbar({super.key, required this.document});

  final CanvasDocument document;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  /// Simple monotonic-enough id for this session — uniqueness within one
  /// document's lifetime is all that's required (ids never leave the
  /// client at this milestone; persistence/real ids are Milestone 3.5's
  /// autosave concern).
  String _nextLayerId() => 'layer_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = canvasControllerProvider(document);
    final controller = ref.read(provider.notifier);
    final state = ref.watch(provider);

    final centerX = state.document.width / 2;
    final centerY = state.document.height / 2;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
        child: Row(
          children: [
            _ToolbarButton(
              icon: Icons.crop_square,
              tooltip: 'Add rectangle',
              onPressed: () => controller.addLayer(
                ShapeCanvasLayer(
                  id: _nextLayerId(),
                  x: centerX - 100,
                  y: centerY - 60,
                  width: 200,
                  height: 120,
                  shapeKind: ShapeKind.rectangle,
                ),
              ),
            ),
            _ToolbarButton(
              icon: Icons.circle_outlined,
              tooltip: 'Add ellipse',
              onPressed: () => controller.addLayer(
                ShapeCanvasLayer(
                  id: _nextLayerId(),
                  x: centerX - 75,
                  y: centerY - 75,
                  width: 150,
                  height: 150,
                  shapeKind: ShapeKind.ellipse,
                ),
              ),
            ),
            _ToolbarButton(
              icon: Icons.text_fields,
              tooltip: 'Add text',
              onPressed: () => controller.addLayer(
                TextCanvasLayer(
                  id: _nextLayerId(),
                  x: centerX - 100,
                  y: centerY - 20,
                  width: 200,
                  height: 40,
                  text: 'Double-click to edit',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed);
  }
}
