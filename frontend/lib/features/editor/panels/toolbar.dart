import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens/spacing_tokens.dart';
import '../canvas/models/canvas_document.dart';
import '../canvas/models/canvas_layer.dart';
import '../canvas/state/canvas_controller.dart';
import '../state/autosave_controller.dart';
import '../state/editor_actions_controller.dart';

/// SCOPE NOTE: add-layer actions only, per this milestone. Deliberately
/// NOT here yet: image upload (needs Milestone 3.2's Cloudinary endpoint
/// wired into a picker UI — a reasonable next increment, not this one),
/// undo/redo (Milestone 3.5), alignment/smart guides (later Phase 3
/// milestones per the blueprint's phase-level feature list).
class EditorToolbar extends ConsumerWidget implements PreferredSizeWidget {
  const EditorToolbar({
    super.key,
    required this.document,
    this.autosaveStatus,
    this.actionState,
    this.onBack,
    this.onExport,
    this.onGenerateVariants,
    this.onPublish,
  });

  final CanvasDocument document;

  /// Publish-pipeline actions (Milestone 3.6). Null when the editor runs
  /// without a backing asset, where there is nothing to export to.
  final EditorActionState? actionState;
  final VoidCallback? onBack;
  final Future<void> Function()? onExport;
  final VoidCallback? onGenerateVariants;
  final VoidCallback? onPublish;

  /// Null when the editor is running without a backing asset (the blank
  /// scratch document EditorScreen defaults to) — there's nothing to save
  /// to, so no indicator is shown rather than one permanently reading
  /// "unsaved".
  final AutosaveStatus? autosaveStatus;

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
            if (onBack != null)
              _ToolbarButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to Content',
                onPressed: onBack,
              ),
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
            const VerticalDivider(width: SpacingTokens.md, indent: 12, endIndent: 12),
            _ToolbarButton(
              icon: Icons.undo,
              tooltip: 'Undo (Ctrl+Z)',
              onPressed: state.canUndo ? controller.undo : null,
            ),
            _ToolbarButton(
              icon: Icons.redo,
              tooltip: 'Redo (Ctrl+Y)',
              onPressed: state.canRedo ? controller.redo : null,
            ),
            const Spacer(),
            if (onExport != null) ...[
              OutlinedButton.icon(
                onPressed: actionState?.busy == true ? null : () => onExport!(),
                icon: actionState?.status == EditorActionStatus.exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export'),
              ),
              const SizedBox(width: SpacingTokens.sm),
              FilledButton.icon(
                onPressed: actionState?.busy == true ? null : onGenerateVariants,
                icon: actionState?.status == EditorActionStatus.generating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_motion, size: 18),
                label: const Text('Generate variants'),
              ),
              const SizedBox(width: SpacingTokens.sm),
              FilledButton.icon(
                onPressed: actionState?.busy == true ? null : onPublish,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Publish'),
              ),
              const SizedBox(width: SpacingTokens.md),
            ],
            if (autosaveStatus != null) _AutosaveIndicator(status: autosaveStatus!),
          ],
        ),
      ),
    );
  }
}

/// Small textual save-state readout. Text rather than a bare spinner:
/// "is my work saved" is a question users ask explicitly, and a spinner
/// alone doesn't distinguish "saving" from "failed to save".
class _AutosaveIndicator extends StatelessWidget {
  const _AutosaveIndicator({required this.status});

  final AutosaveStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, color) = switch (status) {
      AutosaveStatus.idle => ('', theme.colorScheme.onSurfaceVariant),
      AutosaveStatus.pending => ('Unsaved changes', theme.colorScheme.onSurfaceVariant),
      AutosaveStatus.saving => ('Saving…', theme.colorScheme.onSurfaceVariant),
      AutosaveStatus.saved => ('All changes saved', theme.colorScheme.onSurfaceVariant),
      AutosaveStatus.error => ('Save failed — will retry', theme.colorScheme.error),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == AutosaveStatus.saving)
          const Padding(
            padding: EdgeInsets.only(right: SpacingTokens.sm),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;

  /// Nullable so undo/redo can render as genuinely disabled (greyed,
  /// unclickable) when there's nothing to step to, rather than looking
  /// available and silently doing nothing.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed);
  }
}
