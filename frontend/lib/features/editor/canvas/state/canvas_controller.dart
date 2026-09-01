import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/history_controller.dart';
import '../hit_testing.dart';
import '../models/canvas_document.dart';
import '../models/canvas_layer.dart';
import 'canvas_editor_state.dart';

/// Selection + editing logic for one editor session. Deliberately NOT a
/// singleton provider (unlike e.g. authControllerProvider) — a
/// StateNotifierProvider.family.autoDispose instance is created per
/// initial CanvasDocument, matching how a future EditorScreen(assetId)
/// will use it: `ref.watch(canvasControllerProvider(loadedDocument))`.
/// autoDispose so state is cleaned up once nothing is watching it
/// (i.e., once the editor screen is left).
///
/// UNDO/REDO (Milestone 3.5): every method that changes the document
/// records the pre-edit document into [EditorHistory] first, via the
/// single [_applyDocument] chokepoint. Selection changes are deliberately
/// NOT recorded — clicking around a design isn't an edit, and having
/// Ctrl+Z step back through selections instead of actual changes is a
/// well-known way to make undo feel broken.
class CanvasController extends StateNotifier<CanvasEditorState> {
  CanvasController(CanvasDocument initialDocument)
      : super(CanvasEditorState(document: initialDocument));

  final EditorHistory<CanvasDocument> _history = EditorHistory<CanvasDocument>();

  /// True while a continuous gesture (canvas drag, opacity slider) is in
  /// flight. See [beginInteraction] for why this exists.
  bool _interactionActive = false;

  /// Whether the in-flight gesture has already contributed its single
  /// history entry. Reset per gesture — without that reset, only the very
  /// first drag of a session would ever be undoable.
  bool _interactionRecorded = false;

  /// Marks the start of a continuous gesture, so the whole gesture
  /// collapses into ONE undo step.
  ///
  /// Without this, a single drag across the canvas fires
  /// moveSelectedLayerBy on every pointer frame and would push ~60 history
  /// entries per second — the user would then have to press Ctrl+Z
  /// hundreds of times to walk back one drag. Callers that stream updates
  /// (CanvasSurface's pan, the property panel's opacity slider) bracket
  /// them with beginInteraction/[endInteraction]; discrete edits (adding a
  /// layer, committing a number field) need neither.
  void beginInteraction() {
    _interactionActive = true;
    _interactionRecorded = false;
  }

  void endInteraction() {
    _interactionActive = false;
    _interactionRecorded = false;
  }

  /// Hit-tests `artboardPoint` against the current layer stack and
  /// selects whatever's on top there, or clears selection if nothing is.
  /// Used by CanvasSurface's gesture handling (a tap/drag-start position
  /// on the canvas itself).
  void selectLayerAt(Offset artboardPoint) {
    final hit = hitTestLayers(state.document.layers, artboardPoint);
    selectLayerById(hit?.id);
  }

  /// Selects by id directly — used by the layer panel (Milestone 3.4),
  /// where the user clicks a list row rather than a canvas position.
  /// Pass null to clear selection.
  void selectLayerById(String? layerId) {
    state = CanvasEditorState(
      document: state.document,
      selectedLayerId: layerId,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
    );
  }

  void clearSelection() => selectLayerById(null);

  /// Moves the currently-selected layer by `delta` (artboard-space
  /// units, already converted from screen pixels by the caller — see
  /// CanvasSurface). No-ops if nothing is selected, rather than throwing
  /// — a drag gesture starting on empty canvas is a normal, expected
  /// interaction, not an error condition.
  void moveSelectedLayerBy(Offset delta) {
    final selected = _selectedLayer;
    if (selected == null) return;
    updateSelectedLayerGeometry(x: selected.x + delta.dx, y: selected.y + delta.dy);
  }

  /// General geometry update — the property panel's position/size/
  /// rotation/opacity fields all funnel through this one method. Only
  /// the fields actually passed are changed; everything else (including
  /// subtype-specific fields like color) is preserved untouched.
  void updateSelectedLayerGeometry({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
  }) {
    final selectedId = state.selectedLayerId;
    if (selectedId == null) return;

    final updatedLayers = [
      for (final layer in state.document.layers)
        if (layer.id == selectedId)
          layer.copyWithGeometry(
            x: x,
            y: y,
            width: width,
            height: height,
            rotationDegrees: rotationDegrees,
            opacity: opacity,
          )
        else
          layer,
    ];

    _applyDocument(state.document.copyWithLayers(updatedLayers), selectedId);
  }

  /// Sets fill color (ShapeCanvasLayer) or text color (TextCanvasLayer)
  /// on the selected layer. No-ops for an ImageCanvasLayer selection —
  /// color doesn't apply to images, and the property panel doesn't show
  /// a color field for one in the first place (see property_panel.dart),
  /// but this stays a safe no-op rather than throwing in case it's ever
  /// called from somewhere that hasn't checked the layer type first.
  void updateSelectedLayerColor(Color color) {
    final selectedId = state.selectedLayerId;
    if (selectedId == null) return;

    final updatedLayers = [
      for (final layer in state.document.layers)
        if (layer.id == selectedId)
          switch (layer) {
            ShapeCanvasLayer s => s.copyWithFillColor(color),
            TextCanvasLayer t => t.copyWithColor(color),
            ImageCanvasLayer img => img,
            VideoCanvasLayer v => v,
          }
        else
          layer,
    ];

    _applyDocument(state.document.copyWithLayers(updatedLayers), selectedId);
  }

  /// Sets the trim window on the selected video layer (Milestone 9.1).
  /// No-ops for any other layer type — trim only applies to video, and the
  /// property panel only shows the control for a video selection.
  void updateSelectedVideoTrim({double? start, double? end}) {
    final selectedId = state.selectedLayerId;
    if (selectedId == null) return;

    final updatedLayers = [
      for (final layer in state.document.layers)
        if (layer.id == selectedId && layer is VideoCanvasLayer)
          layer.copyWithTrim(trimStartSeconds: start, trimEndSeconds: end)
        else
          layer,
    ];

    _applyDocument(state.document.copyWithLayers(updatedLayers), selectedId);
  }

  /// Adds a new layer to the top of the stack and selects it — used by
  /// the toolbar's "add shape/text" actions (Milestone 3.4).
  void addLayer(CanvasLayer layer) {
    _applyDocument(
      state.document.copyWithLayers([...state.document.layers, layer]),
      layer.id,
    );
  }

  /// Sets the text of the selected [TextCanvasLayer] (double-click on the
  /// canvas, or the property panel's text field). No-op for other types.
  void updateSelectedLayerText(String text) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id && layer is TextCanvasLayer)
          layer.copyWithText(text)
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), id);
  }

  /// Sets the font size of the selected [TextCanvasLayer]. No-op otherwise.
  void updateSelectedTextFontSize(double fontSize) {
    final id = state.selectedLayerId;
    if (id == null || fontSize <= 0) return;
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id && layer is TextCanvasLayer)
          layer.copyWithFontSize(fontSize)
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), id);
  }

  /// Deletes the selected layer and clears selection. No-op if nothing is
  /// selected (or the id no longer resolves to a layer).
  void deleteSelectedLayer() {
    final id = state.selectedLayerId;
    if (id == null) return;
    final remaining =
        state.document.layers.where((l) => l.id != id).toList();
    if (remaining.length == state.document.layers.length) return;
    _applyDocument(state.document.copyWithLayers(remaining), null);
  }

  /// Duplicates the selected layer — a copy offset by (20, 20), inserted
  /// directly above the original in paint order, and selected.
  void duplicateSelectedLayer() {
    final selected = _selectedLayer;
    if (selected == null) return;
    final copy = _cloneWithOffset(selected, _nextId(), const Offset(20, 20));
    final layers = [...state.document.layers];
    final index = layers.indexWhere((l) => l.id == selected.id);
    layers.insert(index + 1, copy);
    _applyDocument(state.document.copyWithLayers(layers), copy.id);
  }

  /// Moves the selected layer one step up the paint stack (towards the
  /// front). No-op if it's already on top or nothing is selected.
  void bringSelectedForward() => _reorderSelected(1);

  /// Moves the selected layer one step down the paint stack (towards the
  /// back). No-op if it's already at the bottom or nothing is selected.
  void sendSelectedBackward() => _reorderSelected(-1);

  void _reorderSelected(int direction) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final layers = [...state.document.layers];
    final i = layers.indexWhere((l) => l.id == id);
    if (i < 0) return;
    final j = i + direction;
    if (j < 0 || j >= layers.length) return;
    final moved = layers.removeAt(i);
    layers.insert(j, moved);
    _applyDocument(state.document.copyWithLayers(layers), id);
  }

  /// Clones any layer type with a new id, offset by [delta]. Kept here (a
  /// switch over the sealed type) rather than on the model so the sealed
  /// exhaustiveness check flags a missing case if a 5th layer type is added.
  CanvasLayer _cloneWithOffset(CanvasLayer layer, String newId, Offset delta) {
    final nx = layer.x + delta.dx;
    final ny = layer.y + delta.dy;
    return switch (layer) {
      ShapeCanvasLayer s => ShapeCanvasLayer(
          id: newId,
          x: nx,
          y: ny,
          width: s.width,
          height: s.height,
          rotationDegrees: s.rotationDegrees,
          opacity: s.opacity,
          shapeKind: s.shapeKind,
          fillColor: s.fillColor,
        ),
      TextCanvasLayer t => TextCanvasLayer(
          id: newId,
          x: nx,
          y: ny,
          width: t.width,
          height: t.height,
          rotationDegrees: t.rotationDegrees,
          opacity: t.opacity,
          text: t.text,
          fontSize: t.fontSize,
          color: t.color,
          fontFamily: t.fontFamily,
        ),
      ImageCanvasLayer i => ImageCanvasLayer(
          id: newId,
          x: nx,
          y: ny,
          width: i.width,
          height: i.height,
          rotationDegrees: i.rotationDegrees,
          opacity: i.opacity,
          imageUrl: i.imageUrl,
        ),
      VideoCanvasLayer v => VideoCanvasLayer(
          id: newId,
          x: nx,
          y: ny,
          width: v.width,
          height: v.height,
          rotationDegrees: v.rotationDegrees,
          opacity: v.opacity,
          videoUrl: v.videoUrl,
          posterUrl: v.posterUrl,
          trimStartSeconds: v.trimStartSeconds,
          trimEndSeconds: v.trimEndSeconds,
        ),
    };
  }

  int _idCounter = 0;
  String _nextId() =>
      'layer_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  /// Replaces the entire document in one undoable edit — used by
  /// whole-canvas transforms like "apply brand kit" (Milestone 9.3), where
  /// many layers change at once and there is no single selected layer the
  /// change belongs to. Selection is cleared for the same reason undo does
  /// it: the previously-selected layer may have been restyled out from
  /// under the property panel.
  void replaceDocument(CanvasDocument document) {
    _applyDocument(document, null);
  }

  /// Steps back one edit (Ctrl+Z). No-ops when there's nothing to undo.
  ///
  /// Selection is intentionally cleared on undo: the restored document
  /// may not contain the currently-selected layer at all (undoing an
  /// "add layer"), and a selectedLayerId pointing at a layer that no
  /// longer exists would leave the property panel rendering stale
  /// controls for a phantom layer.
  void undo() {
    final restored = _history.undo(state.document);
    if (restored == null) return;
    _emit(restored, null);
  }

  /// Steps forward one undone edit (Ctrl+Y / Ctrl+Shift+Z).
  void redo() {
    final restored = _history.redo(state.document);
    if (restored == null) return;
    _emit(restored, null);
  }

  /// The single write path for document *edits*. Records history (once
  /// per discrete edit, or once per continuous gesture — see
  /// [beginInteraction]) and then emits.
  void _applyDocument(CanvasDocument document, String? selectedLayerId) {
    if (!_interactionActive) {
      _history.record(state.document);
    } else if (!_interactionRecorded) {
      // First frame of a continuous gesture: record the pre-gesture
      // document once, then suppress until the gesture ends.
      _history.record(state.document);
      _interactionRecorded = true;
    }
    _emit(document, selectedLayerId);
  }

  /// Emits without touching history — used by undo/redo, which move
  /// through the stack rather than adding to it.
  void _emit(CanvasDocument document, String? selectedLayerId) {
    state = CanvasEditorState(
      document: document,
      selectedLayerId: selectedLayerId,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
    );
  }

  CanvasLayer? get _selectedLayer {
    final id = state.selectedLayerId;
    if (id == null) return null;
    for (final layer in state.document.layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }
}

final canvasControllerProvider = StateNotifierProvider.autoDispose
    .family<CanvasController, CanvasEditorState, CanvasDocument>(
  (ref, initialDocument) => CanvasController(initialDocument),
);
