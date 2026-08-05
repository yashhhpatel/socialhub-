import '../models/canvas_document.dart';

class CanvasEditorState {
  const CanvasEditorState({
    required this.document,
    this.selectedLayerId,
    this.canUndo = false,
    this.canRedo = false,
  });

  final CanvasDocument document;
  final String? selectedLayerId;

  /// Mirrored out of the controller's EditorHistory (Milestone 3.5) so the
  /// toolbar can enable/disable its undo/redo buttons by watching state
  /// like any other widget, instead of reaching into the notifier and
  /// reading a value that produces no rebuild when it changes.
  final bool canUndo;
  final bool canRedo;
}
