import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_error_message.dart';
import '../brand_kit/data/repositories/api_brand_kit_repository.dart';
import '../collaboration/presentation/widgets/comments_drawer.dart';
import '../publish/presentation/widgets/publish_modal.dart';
import '../templates/data/repositories/api_templates_repository.dart';
import 'canvas/brand_kit_application.dart';
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
        // Delete / Backspace remove the selected layer. When a text field
        // (e.g. the property panel) has focus it consumes these first, so
        // typing a caption never deletes the layer.
        const SingleActivator(LogicalKeyboardKey.delete):
            controller.deleteSelectedLayer,
        const SingleActivator(LogicalKeyboardKey.backspace):
            controller.deleteSelectedLayer,
        // Ctrl/⌘+D duplicates the selection.
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            controller.duplicateSelectedLayer,
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
            controller.duplicateSelectedLayer,
        // Arrow keys nudge the selection 1px; Shift+arrow nudges 10px. A
        // focused text field consumes these first, so typing isn't affected.
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            controller.nudgeSelected(-1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            controller.nudgeSelected(1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            controller.nudgeSelected(0, -1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            controller.nudgeSelected(0, 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
            controller.nudgeSelected(-10, 0),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
            controller.nudgeSelected(10, 0),
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
            controller.nudgeSelected(0, -10),
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () =>
            controller.nudgeSelected(0, 10),
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
            onPublish: () => showPublishModal(context, assetId),
            onApplyBrandKit: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final kit = await ref.read(brandKitRepositoryProvider).get();
                if (kit.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Your brand kit is empty — set colours or fonts first.'),
                    ),
                  );
                  return;
                }
                controller.replaceDocument(
                  applyBrandKit(ref.read(provider).document, kit),
                );
                messenger.showSnackBar(
                  const SnackBar(content: Text('Brand kit applied to this design.')),
                );
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Could not apply brand kit: ${describeApiError(error)}')),
                );
              }
            },
            onSaveAsTemplate: () async {
              await ref.read(autosaveControllerProvider(assetId).notifier).flush();
              if (!context.mounted) return;
              final details = await _promptTemplateDetails(context);
              if (details == null || !context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(templatesRepositoryProvider).create(
                      name: details.name,
                      category: details.category,
                      document: ref.read(provider).document,
                    );
                messenger.showSnackBar(
                  const SnackBar(content: Text('Saved as a template.')),
                );
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Could not save template: ${describeApiError(error)}')),
                );
              }
            },
            // Opens the comment sidebar (Milestone 13.3).
            hasComments: true,
          ),
          // Comment thread as an end-drawer, toggled from the toolbar.
          endDrawer: CommentsDrawer(assetId: assetId),
          body: Column(
            children: [
              Expanded(
                child: Row(
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Prompts for a template name (required) and optional category when saving
/// the current design as a template (Milestone 9.4). Returns null if the
/// user cancels or leaves the name blank.
Future<({String name, String? category})?> _promptTemplateDetails(
  BuildContext context,
) {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();

  return showDialog<({String name, String? category})?>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Save as template'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Template name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: categoryController,
            decoration: const InputDecoration(labelText: 'Category (optional)'),
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
            final name = nameController.text.trim();
            if (name.isEmpty) return; // name is required; keep the dialog open
            final category = categoryController.text.trim();
            Navigator.pop(
              context,
              (name: name, category: category.isEmpty ? null : category),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(() {
    nameController.dispose();
    categoryController.dispose();
  });
}
