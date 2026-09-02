import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/history_controller.dart';
import '../hit_testing.dart';
import '../models/canvas_document.dart';
import '../models/canvas_layer.dart';
import 'canvas_editor_state.dart';

/// Where to align a layer against the artboard (used by the property panel's
/// Arrange section — see [CanvasController.alignSelectedToArtboard]).
enum LayerAlignment { left, hCenter, right, top, vCenter, bottom }

/// The eight resize handles around a selected layer (compass points), used by
/// the on-canvas drag-to-resize — see [CanvasController.resizeSelectedByHandle].
enum ResizeHandle { nw, n, ne, e, se, s, sw, w }

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
    if (selected == null || selected.locked) return;
    updateSelectedLayerGeometry(x: selected.x + delta.dx, y: selected.y + delta.dy);
  }

  /// Nudges the selected layer by a fixed artboard-space delta — the editor's
  /// arrow-key handling. One discrete undo step per call. No-op when nothing
  /// is selected or the layer is locked.
  void nudgeSelected(double dx, double dy) {
    final selected = _selectedLayer;
    if (selected == null || selected.locked) return;
    updateSelectedLayerGeometry(x: selected.x + dx, y: selected.y + dy);
  }

  /// Mirrors the selected layer horizontally or vertically.
  void flipSelected({required bool horizontal}) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id)
          layer.copyWithFlags(
            flipH: horizontal ? !layer.flipH : null,
            flipV: horizontal ? null : !layer.flipV,
          )
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), id);
  }

  /// Resizes the selected layer by dragging one of the eight handles, in
  /// artboard-space [delta]. The edge/corner OPPOSITE the dragged handle stays
  /// fixed. [lockAspect] (Shift on a corner) preserves the aspect ratio. Sizes
  /// clamp to [minSize]. Called only for unrotated layers by the surface, so
  /// the anchor maths is exact.
  void resizeSelectedByHandle(
    ResizeHandle handle,
    Offset delta, {
    bool lockAspect = false,
    double minSize = 8,
  }) {
    final sel = _selectedLayer;
    if (sel == null || sel.locked) return;

    final left = handle == ResizeHandle.nw ||
        handle == ResizeHandle.w ||
        handle == ResizeHandle.sw;
    final right = handle == ResizeHandle.ne ||
        handle == ResizeHandle.e ||
        handle == ResizeHandle.se;
    final top = handle == ResizeHandle.nw ||
        handle == ResizeHandle.n ||
        handle == ResizeHandle.ne;
    final bottom = handle == ResizeHandle.sw ||
        handle == ResizeHandle.s ||
        handle == ResizeHandle.se;
    final isCorner = (left || right) && (top || bottom);

    final rightEdge = sel.x + sel.width;
    final bottomEdge = sel.y + sel.height;

    var w = sel.width;
    var h = sel.height;
    if (left) w = sel.width - delta.dx;
    if (right) w = sel.width + delta.dx;
    if (top) h = sel.height - delta.dy;
    if (bottom) h = sel.height + delta.dy;

    if (lockAspect && isCorner && sel.height != 0) {
      // Honour the width change and derive height to keep the ratio.
      h = w / (sel.width / sel.height);
    }

    w = w < minSize ? minSize : w;
    h = h < minSize ? minSize : h;

    var x = sel.x;
    var y = sel.y;
    if (left) x = rightEdge - w; // right edge stays fixed
    if (top) y = bottomEdge - h; // bottom edge stays fixed

    updateSelectedLayerGeometry(x: x, y: y, width: w, height: h);
  }

  /// Aligns the selected layer against the artboard edges/centre.
  void alignSelectedToArtboard(LayerAlignment alignment) {
    final selected = _selectedLayer;
    if (selected == null || selected.locked) return;
    final doc = state.document;
    switch (alignment) {
      case LayerAlignment.left:
        updateSelectedLayerGeometry(x: 0);
      case LayerAlignment.hCenter:
        updateSelectedLayerGeometry(x: (doc.width - selected.width) / 2);
      case LayerAlignment.right:
        updateSelectedLayerGeometry(x: doc.width - selected.width);
      case LayerAlignment.top:
        updateSelectedLayerGeometry(y: 0);
      case LayerAlignment.vCenter:
        updateSelectedLayerGeometry(y: (doc.height - selected.height) / 2);
      case LayerAlignment.bottom:
        updateSelectedLayerGeometry(y: doc.height - selected.height);
    }
  }

  /// Sets the artboard's background fill. Undoable like any edit.
  void setBackgroundColor(Color color) {
    _applyDocument(
      state.document.copyWith(backgroundColor: color),
      state.selectedLayerId,
    );
  }

  /// Resizes the artboard (a "Resize" preset). Layers keep their positions.
  void resizeArtboard(double width, double height) {
    if (width <= 0 || height <= 0) return;
    _applyDocument(
      state.document.copyWith(width: width, height: height),
      state.selectedLayerId,
    );
  }

  /// Locks/unlocks a layer by id (from the Layers panel, not necessarily the
  /// selection). A locked layer can't be moved or selected on the canvas.
  void setLayerLocked(String id, bool locked) =>
      _setFlags(id, locked: locked);

  /// Shows/hides a layer by id. A hidden layer isn't painted or hit-tested.
  void setLayerHidden(String id, bool hidden) =>
      _setFlags(id, hidden: hidden);

  void _setFlags(String id, {bool? locked, bool? hidden}) {
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id)
          layer.copyWithFlags(locked: locked, hidden: hidden)
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerId);
  }

  /// Bold / italic / alignment / line-height on the selected text layer.
  void updateSelectedTextFormat({
    bool? bold,
    bool? italic,
    TextAlign? align,
    double? lineHeight,
  }) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id && layer is TextCanvasLayer)
          layer.copyWithTextFormat(
            bold: bold,
            italic: italic,
            align: align,
            lineHeight: lineHeight,
          )
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), id);
  }

  /// Sets (or clears, with null) the font family of the selected text layer.
  void updateSelectedTextFontFamily(String? fontFamily) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id && layer is TextCanvasLayer)
          layer.copyWithFontFamily(fontFamily)
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), id);
  }

  /// Border colour/width and corner radius on the selected shape layer.
  void updateSelectedShapeStyle({
    Color? strokeColor,
    double? strokeWidth,
    double? cornerRadius,
    bool clearStroke = false,
  }) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id && layer is ShapeCanvasLayer)
          layer.copyWithShapeStyle(
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            cornerRadius: cornerRadius,
            clearStroke: clearStroke,
          )
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), id);
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

  /// Moves the selected layer to the very top / bottom of the stack.
  void bringSelectedToFront() => _reorderSelectedTo(true);
  void sendSelectedToBack() => _reorderSelectedTo(false);

  void _reorderSelectedTo(bool front) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final layers = [...state.document.layers];
    final i = layers.indexWhere((l) => l.id == id);
    if (i < 0) return;
    if (front && i == layers.length - 1) return; // already on top
    if (!front && i == 0) return; // already at the bottom
    final moved = layers.removeAt(i);
    front ? layers.add(moved) : layers.insert(0, moved);
    _applyDocument(state.document.copyWithLayers(layers), id);
  }

  /// Session clipboard for copy/paste — the last copied (or cut) layer.
  CanvasLayer? _clipboard;
  bool get hasClipboard => _clipboard != null;

  /// Copies the selected layer to the clipboard. No document change.
  void copySelectedLayer() {
    final selected = _selectedLayer;
    if (selected != null) _clipboard = selected;
  }

  /// Copies then deletes the selected layer.
  void cutSelectedLayer() {
    final selected = _selectedLayer;
    if (selected == null) return;
    _clipboard = selected;
    deleteSelectedLayer();
  }

  /// Pastes the clipboard layer as an offset copy on top of the stack, and
  /// selects it. No-op when the clipboard is empty.
  void pasteLayer() {
    final source = _clipboard;
    if (source == null) return;
    final copy = _cloneWithOffset(source, _nextId(), const Offset(20, 20));
    _applyDocument(
      state.document.copyWithLayers([...state.document.layers, copy]),
      copy.id,
    );
  }

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
    // A duplicate is always unlocked and visible so it can be worked on
    // immediately, even if the original was locked/hidden.
    return switch (layer) {
      ShapeCanvasLayer s => ShapeCanvasLayer(
          id: newId,
          x: nx,
          y: ny,
          width: s.width,
          height: s.height,
          rotationDegrees: s.rotationDegrees,
          opacity: s.opacity,
          flipH: s.flipH,
          flipV: s.flipV,
          shapeKind: s.shapeKind,
          fillColor: s.fillColor,
          strokeColor: s.strokeColor,
          strokeWidth: s.strokeWidth,
          cornerRadius: s.cornerRadius,
        ),
      TextCanvasLayer t => TextCanvasLayer(
          id: newId,
          x: nx,
          y: ny,
          width: t.width,
          height: t.height,
          rotationDegrees: t.rotationDegrees,
          opacity: t.opacity,
          flipH: t.flipH,
          flipV: t.flipV,
          text: t.text,
          fontSize: t.fontSize,
          color: t.color,
          fontFamily: t.fontFamily,
          bold: t.bold,
          italic: t.italic,
          align: t.align,
          lineHeight: t.lineHeight,
        ),
      ImageCanvasLayer i => ImageCanvasLayer(
          id: newId,
          x: nx,
          y: ny,
          width: i.width,
          height: i.height,
          rotationDegrees: i.rotationDegrees,
          opacity: i.opacity,
          flipH: i.flipH,
          flipV: i.flipV,
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
          flipH: v.flipH,
          flipV: v.flipV,
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
