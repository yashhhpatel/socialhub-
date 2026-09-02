import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_message.dart';
import '../../../core/theme/tokens/spacing_tokens.dart';
import '../../media_library/data/api_media_repository.dart';
import '../../media_library/domain/media_item.dart';
import '../canvas/models/canvas_document.dart';
import '../canvas/models/canvas_layer.dart';
import '../canvas/state/canvas_controller.dart';
import '../state/autosave_controller.dart';
import '../state/editor_actions_controller.dart';

/// Artboard size presets offered by the toolbar's "Resize" menu — the common
/// social formats, so a design can be reframed for a platform in one click.
const _artboardPresets = <({String label, double width, double height})>[
  (label: 'Instagram Square · 1080×1080', width: 1080, height: 1080),
  (label: 'Instagram Portrait · 1080×1350', width: 1080, height: 1350),
  (label: 'Story / Reel · 1080×1920', width: 1080, height: 1920),
  (label: 'Facebook Post · 1200×630', width: 1200, height: 630),
  (label: 'X Post · 1600×900', width: 1600, height: 900),
  (label: 'LinkedIn · 1200×627', width: 1200, height: 627),
];

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
    this.onApplyBrandKit,
    this.onSaveAsTemplate,
    this.hasComments = false,
  });

  final CanvasDocument document;

  /// Publish-pipeline actions (Milestone 3.6). Null when the editor runs
  /// without a backing asset, where there is nothing to export to.
  final EditorActionState? actionState;
  final VoidCallback? onBack;
  final Future<void> Function()? onExport;
  final VoidCallback? onGenerateVariants;
  final VoidCallback? onPublish;

  /// Applies the org's brand kit across the whole canvas (Milestone 9.3).
  /// Null when the editor runs without a backing asset.
  final VoidCallback? onApplyBrandKit;

  /// Saves the current design as a reusable template (Milestone 9.4). Null
  /// when the editor runs without a backing asset.
  final VoidCallback? onSaveAsTemplate;

  /// Whether a comment sidebar (end-drawer) is available to open
  /// (Milestone 13.3). Only true for the real asset-backed editor.
  final bool hasComments;

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

  /// Prompts for a video URL (and optional poster still) and adds a video
  /// layer centered on the artboard (Milestone 9.1). A URL rather than a
  /// file picker keeps this milestone to the canvas engine — the upload +
  /// transcode pipeline is Milestone 9.2's concern.
  Future<void> _promptAddVideo(
    BuildContext context,
    CanvasController controller,
    double centerX,
    double centerY,
  ) async {
    final videoController = TextEditingController();
    final posterController = TextEditingController();

    final urls = await showDialog<({String video, String? poster})?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: videoController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Video URL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: posterController,
              decoration: const InputDecoration(labelText: 'Poster image URL (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final video = videoController.text.trim();
              if (video.isEmpty) return;
              final poster = posterController.text.trim();
              Navigator.pop(
                context,
                (video: video, poster: poster.isEmpty ? null : poster),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).whenComplete(() {
      videoController.dispose();
      posterController.dispose();
    });

    if (urls == null) return;
    controller.addLayer(
      VideoCanvasLayer(
        id: _nextLayerId(),
        x: centerX - 160,
        y: centerY - 90,
        width: 320,
        height: 180,
        videoUrl: urls.video,
        posterUrl: urls.poster,
      ),
    );
  }

  /// Opens a picker of the org's uploaded images and drops the chosen one in
  /// as an image layer, centred on the artboard. Reuses the media library —
  /// the same catalogue the Create Post & Publish page uploads to.
  Future<void> _pickAndAddImage(
    BuildContext context,
    CanvasController controller,
    double centerX,
    double centerY,
    CanvasDocument doc,
  ) async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _ImagePickerDialog(),
    );
    if (url == null) return;
    // A generous default box; images paint BoxFit.cover, and the user can
    // resize from the property panel.
    final side = math.min(doc.width, doc.height) * 0.6;
    controller.addLayer(
      ImageCanvasLayer(
        id: _nextLayerId(),
        x: centerX - side / 2,
        y: centerY - side / 2,
        width: side,
        height: side,
        imageUrl: url,
      ),
    );
  }

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
            _ToolbarButton(
              icon: Icons.image_outlined,
              tooltip: 'Add image',
              onPressed: () => _pickAndAddImage(
                context,
                controller,
                centerX,
                centerY,
                state.document,
              ),
            ),
            _ToolbarButton(
              icon: Icons.videocam_outlined,
              tooltip: 'Add video',
              onPressed: () => _promptAddVideo(context, controller, centerX, centerY),
            ),
            const VerticalDivider(width: SpacingTokens.md, indent: 12, endIndent: 12),
            PopupMenuButton<({String label, double width, double height})>(
              tooltip: 'Resize artboard',
              icon: const Icon(Icons.aspect_ratio),
              onSelected: (preset) =>
                  controller.resizeArtboard(preset.width, preset.height),
              itemBuilder: (context) => [
                for (final preset in _artboardPresets)
                  PopupMenuItem(value: preset, child: Text(preset.label)),
              ],
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
            if (onApplyBrandKit != null || onSaveAsTemplate != null)
              const VerticalDivider(width: SpacingTokens.md, indent: 12, endIndent: 12),
            if (onApplyBrandKit != null)
              _ToolbarButton(
                icon: Icons.palette_outlined,
                tooltip: 'Apply brand kit',
                onPressed: actionState?.busy == true ? null : onApplyBrandKit,
              ),
            if (onSaveAsTemplate != null)
              _ToolbarButton(
                icon: Icons.bookmark_add_outlined,
                tooltip: 'Save as template',
                onPressed: actionState?.busy == true ? null : onSaveAsTemplate,
              ),
            const Spacer(),
            if (hasComments) ...[
              // Builder so Scaffold.of resolves the editor's Scaffold (this
              // toolbar is its appBar), letting the button open the comment
              // end-drawer.
              Builder(
                builder: (context) => _ToolbarButton(
                  icon: Icons.forum_outlined,
                  tooltip: 'Comments',
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
            ],
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

/// Picks one image from the org's media library to place on the canvas.
/// Pops with the chosen image URL (or null on cancel).
class _ImagePickerDialog extends ConsumerWidget {
  const _ImagePickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final library = ref.watch(mediaLibraryProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Add an image', style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.md),
              Flexible(
                child: library.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Could not load your media: ${describeApiError(e)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  data: (items) {
                    final images = items.where((m) => !m.isVideo).toList();
                    if (images.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(SpacingTokens.lg),
                        child: Text(
                          'No images in your library yet. Upload some from '
                          'Create Post & Publish first.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 140,
                        mainAxisSpacing: SpacingTokens.sm,
                        crossAxisSpacing: SpacingTokens.sm,
                        childAspectRatio: 1,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, i) => _ImageTile(item: images[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).pop(item.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
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
