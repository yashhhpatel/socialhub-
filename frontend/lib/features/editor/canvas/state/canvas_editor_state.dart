import '../models/canvas_document.dart';

class CanvasEditorState {
  const CanvasEditorState({
    required this.document,
    this.selectedLayerIds = const {},
    this.canUndo = false,
    this.canRedo = false,
  });

  final CanvasDocument document;

  /// The set of selected layer ids. Multi-select (Milestone: batch 3) — a
  /// Set rather than a single id so several layers can be moved/aligned at
  /// once. Empty means nothing is selected.
  final Set<String> selectedLayerIds;

  /// Back-compat convenience: the single selected layer id, or null when zero
  /// or many are selected. The property panel's per-layer editing and the
  /// on-canvas resize/rotate handles only apply to a single selection, so they
  /// read this and no-op when it's null.
  String? get selectedLayerId =>
      selectedLayerIds.length == 1 ? selectedLayerIds.first : null;

  bool isSelected(String id) => selectedLayerIds.contains(id);

  /// Mirrored out of the controller's EditorHistory (Milestone 3.5) so the
  /// toolbar can enable/disable its undo/redo buttons by watching state
  /// like any other widget, instead of reaching into the notifier and
  /// reading a value that produces no rebuild when it changes.
  final bool canUndo;
  final bool canRedo;
}
