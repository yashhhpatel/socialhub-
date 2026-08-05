import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_error_message.dart';
import 'canvas/models/canvas_document.dart';
import 'canvas/state/canvas_controller.dart';
import 'canvas/widgets/canvas_surface.dart';
import 'panels/layer_panel.dart';
import 'panels/property_panel.dart';
import 'panels/toolbar.dart';
import 'state/autosave_controller.dart';
import 'state/editor_actions_controller.dart';

/// Route target for `/editor/:assetId` (Milestone 3.6).
///
/// Loads the saved canvas, then hands it to the editor proper. Before
/// this milestone EditorScreen existed but was imported by nothing —
/// the canvas engine (3.3), panels (3.4) and undo/redo + autosave (3.5)
/// were all unreachable from the running app.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(editorDocumentProvider(assetId));

    return document.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not open this design: ${describeApiError(error)}'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/content'),
                child: const Text('Back to Content'),
              ),
            ],
          ),
        ),
      ),
      data: (doc) => _EditorWorkspace(assetId: assetId, document: doc),
    );
  }
}

class _EditorWorkspace extends ConsumerWidget {
  const _EditorWorkspace({required this.assetId, required this.document});

  final String assetId;
  final CanvasDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = canvasControllerProvider(document);
    final controller = ref.read(provider.notifier);

    // Feed every committed document change into the debounced autosave.
    // ref.listen (not watch) because this is a side effect, not something
    // the build output depends on — watching would rebuild the whole
    // editor on each canvas mutation for no visual reason.
    ref.listen<CanvasDocument>(
      provider.select((s) => s.document),
      (previous, next) {
        if (previous == null || identical(previous, next)) return;
        ref.read(autosaveControllerProvider(assetId).notifier).onDocumentChanged(next);
      },
    );

    // Surface export/variant results, which happen outside the widget
    // tree and would otherwise complete invisibly.
    ref.listen<EditorActionState>(editorActionsProvider(assetId), (_, next) {
      final message = next.message;
      if (message == null || next.busy) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: next.status == EditorActionStatus.failed
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
    });

    final autosaveStatus = ref.watch(autosaveControllerProvider(assetId)).status;
    final actions = ref.watch(editorActionsProvider(assetId));

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
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            ref.read(autosaveControllerProvider(assetId).notifier).flush(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: EditorToolbar(
            document: document,
            autosaveStatus: autosaveStatus,
            actionState: actions,
            onBack: () => context.go('/content'),
            onExport: () async {
              // Flush pending canvas edits first: exporting a design whose
              // last change hasn't been saved would attach a render that
              // doesn't match the persisted canvasJson.
              await ref.read(autosaveControllerProvider(assetId).notifier).flush();
              final current = ref.read(provider).document;
              await ref
                  .read(editorActionsProvider(assetId).notifier)
                  .exportMasterRender(current);
            },
            onGenerateVariants: () =>
                ref.read(editorActionsProvider(assetId).notifier).generateVariants(),
          ),
          body: Row(
            children: [
              LayerPanel(document: document),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CanvasSurface(document: document),
                ),
              ),
              const VerticalDivider(width: 1),
              PropertyPanel(document: document),
            ],
          ),
        ),
      ),
    );
  }
}
