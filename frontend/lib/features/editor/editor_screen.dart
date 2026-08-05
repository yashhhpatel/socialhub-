import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'canvas/models/canvas_document.dart';
import 'canvas/state/canvas_controller.dart';
import 'canvas/widgets/canvas_surface.dart';
import 'panels/layer_panel.dart';
import 'panels/property_panel.dart';
import 'panels/toolbar.dart';
import 'state/autosave_controller.dart';

/// Assembles the canvas engine (Milestone 3.3) with the panels/toolbar
/// (3.4) and, as of Milestone 3.5, undo/redo shortcuts plus debounced
/// autosave.
///
/// NOTE: the blueprint lists this file as "modified" for Milestone 3.4,
/// but it never existed before now — Milestone 3.3 built only the
/// canvas engine itself (files under canvas/), not a screen around it.
/// Created there instead, flagged the same way as every other case in
/// this project where the blueprint's literal file list didn't quite
/// match what the milestone needed to actually be buildable/verifiable.
///
/// `assetId` is optional. Passing one turns on autosave against
/// `PATCH /content/assets/:id`; omitting it gives a local scratch
/// artboard with undo/redo but no persistence. That split exists because
/// there is still no route into this screen carrying a real asset id
/// (wiring the editor into app_router.dart with an asset-loading route is
/// its own increment) — without the optional form, this milestone's
/// undo/redo work would be unreachable and unverifiable until that
/// routing exists.
class EditorScreen extends ConsumerStatefulWidget {
  EditorScreen({super.key, CanvasDocument? initialDocument, this.assetId})
      : document = initialDocument ?? const CanvasDocument(width: 1080, height: 1080);

  final CanvasDocument document;
  final String? assetId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = canvasControllerProvider(widget.document);
    final controller = ref.read(provider.notifier);
    final assetId = widget.assetId;

    // Feed every committed document change into the debounced autosave.
    // ref.listen (not watch) because this is a side effect, not something
    // the build output depends on — watching would rebuild the whole
    // editor on each canvas mutation for no visual reason.
    if (assetId != null) {
      ref.listen<CanvasDocument>(
        provider.select((s) => s.document),
        (previous, next) {
          if (previous == null || identical(previous, next)) return;
          ref.read(autosaveControllerProvider(assetId).notifier).onDocumentChanged(next);
        },
      );
    }

    final autosaveStatus =
        assetId == null ? null : ref.watch(autosaveControllerProvider(assetId)).status;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): controller.redo,
        // Ctrl+Shift+Z is the other near-universal redo binding; both are
        // bound rather than picking one, since which is "correct" is
        // genuinely split across the design tools users come from.
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            controller.redo,
        // macOS users on web send meta, not control.
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            controller.redo,
        if (assetId != null)
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
              ref.read(autosaveControllerProvider(assetId).notifier).flush(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: EditorToolbar(document: widget.document, autosaveStatus: autosaveStatus),
          body: Row(
            children: [
              LayerPanel(document: widget.document),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CanvasSurface(document: widget.document),
                ),
              ),
              const VerticalDivider(width: 1),
              PropertyPanel(document: widget.document),
            ],
          ),
        ),
      ),
    );
  }
}
