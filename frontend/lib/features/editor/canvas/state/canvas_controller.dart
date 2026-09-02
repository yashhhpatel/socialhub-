import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/history_controller.dart';
import '../hit_testing.dart';
import '../models/canvas_document.dart';
import '../models/canvas_layer.dart';
import 'canvas_editor_state.dart';

/// Where to align a layer against the artboard, or selected layers against
/// their common bounding box (property panel's Arrange / multi-select).
enum LayerAlignment { left, hCenter, right, top, vCenter, bottom }

/// The eight resize handles around a selected layer (compass points), used by
/// the on-canvas drag-to-resize — see [CanvasController.resizeSelectedByHandle].
enum ResizeHandle { nw, n, ne, e, se, s, sw, w }

/// Axis for distributing three-or-more selected layers evenly.
enum DistributeAxis { horizontal, vertical }

/// Case transform applied to a text layer's content.
enum TextCase { upper, lower, title }

/// Selection + editing logic for one editor session. Selection is a SET of
/// layer ids (multi-select); single-layer operations act on the sole selected
/// layer via [CanvasEditorState.selectedLayerId] and no-op when several are
/// selected.
///
/// UNDO/REDO (Milestone 3.5): every method that changes the document records
/// the pre-edit document into [EditorHistory] first, via the single
/// [_applyDocument] chokepoint. Selection changes are deliberately NOT
/// recorded.
class CanvasController extends StateNotifier<CanvasEditorState> {
  CanvasController(CanvasDocument initialDocument)
      : super(CanvasEditorState(document: initialDocument));

  final EditorHistory<CanvasDocument> _history = EditorHistory<CanvasDocument>();

  bool _interactionActive = false;
  bool _interactionRecorded = false;

  /// Marks the start of a continuous gesture, so the whole gesture collapses
  /// into ONE undo step (see the original note in earlier milestones).
  void beginInteraction() {
    _interactionActive = true;
    _interactionRecorded = false;
  }

  void endInteraction() {
    _interactionActive = false;
    _interactionRecorded = false;
  }

  // ---- Selection ---------------------------------------------------------

  /// Hit-tests `artboardPoint` and selects whatever's on top there. With
  /// [additive] (Shift-click) the hit layer is toggled in/out of the current
  /// selection instead of replacing it; a miss clears (unless additive).
  void selectLayerAt(Offset artboardPoint, {bool additive = false}) {
    final hit = hitTestLayers(state.document.layers, artboardPoint);
    if (hit == null) {
      if (!additive) clearSelection();
      return;
    }
    if (additive) {
      toggleLayerSelection(hit.id);
    } else if (!state.isSelected(hit.id)) {
      // Clicking an already-selected layer keeps the whole (possibly multi)
      // selection so it can be dragged as a group; clicking a new one selects
      // just it.
      _setSelection({hit.id});
    }
  }

  /// Selects a single layer by id (or clears with null) — the Layers panel.
  void selectLayerById(String? layerId) =>
      _setSelection(layerId == null ? const {} : {layerId});

  /// Adds/removes a layer from the current selection (Shift-click).
  void toggleLayerSelection(String id) {
    final next = {...state.selectedLayerIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    _setSelection(next);
  }

  /// Selects every (visible, unlocked) layer whose box intersects [rect] — the
  /// marquee drag. An empty rect selection clears.
  void selectLayersInRect(Rect rect) {
    final ids = <String>{
      for (final l in state.document.layers)
        if (!l.hidden && !l.locked &&
            rect.overlaps(Rect.fromLTWH(l.x, l.y, l.width, l.height)))
          l.id,
    };
    _setSelection(ids);
  }

  void clearSelection() => _setSelection(const {});

  void _setSelection(Set<String> ids) {
    state = CanvasEditorState(
      document: state.document,
      selectedLayerIds: ids,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
    );
  }

  // ---- Move / nudge (multi) ---------------------------------------------

  /// Moves every selected (unlocked) layer by `delta` (artboard units). No-op
  /// when nothing is selected.
  void moveSelectedLayerBy(Offset delta) {
    final ids = state.selectedLayerIds;
    if (ids.isEmpty) return;
    final updated = [
      for (final layer in state.document.layers)
        if (ids.contains(layer.id) && !layer.locked)
          layer.copyWithGeometry(x: layer.x + delta.dx, y: layer.y + delta.dy)
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), ids);
  }

  /// Nudges the selection by a fixed delta — the editor's arrow keys.
  void nudgeSelected(double dx, double dy) => moveSelectedLayerBy(Offset(dx, dy));

  // ---- Single-layer geometry / style ------------------------------------

  /// General geometry update for the SINGLE selected layer (property panel).
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
    _applyDocument(state.document.copyWithLayers(updatedLayers), state.selectedLayerIds);
  }

  /// Resizes the single selected layer by dragging one of the eight handles,
  /// in artboard-space [delta]. The edge/corner OPPOSITE the dragged handle
  /// stays fixed. [lockAspect] (Shift on a corner) preserves the aspect ratio.
  /// Only called for unrotated single selections, so the anchor maths is exact.
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
      h = w / (sel.width / sel.height);
    }

    w = w < minSize ? minSize : w;
    h = h < minSize ? minSize : h;

    var x = sel.x;
    var y = sel.y;
    if (left) x = rightEdge - w;
    if (top) y = bottomEdge - h;

    updateSelectedLayerGeometry(x: x, y: y, width: w, height: h);
  }

  /// Mirrors every selected layer horizontally or vertically.
  void flipSelected({required bool horizontal}) {
    final ids = state.selectedLayerIds;
    if (ids.isEmpty) return;
    final updated = [
      for (final layer in state.document.layers)
        if (ids.contains(layer.id))
          layer.copyWithFlags(
            flipH: horizontal ? !layer.flipH : null,
            flipV: horizontal ? null : !layer.flipV,
          )
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), ids);
  }

  // ---- Alignment / distribute / match size ------------------------------

  /// Aligns the single selected layer against the ARTBOARD edges/centre.
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

  /// Aligns all selected layers against their common bounding box (needs 2+).
  void alignSelectedToSelection(LayerAlignment alignment) {
    final sels = _selectedLayers;
    if (sels.length < 2) return;
    final b = _boundsOf(sels);
    final ids = state.selectedLayerIds;
    final updated = [
      for (final layer in state.document.layers)
        if (ids.contains(layer.id) && !layer.locked)
          _alignedInBounds(layer, b, alignment)
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), ids);
  }

  CanvasLayer _alignedInBounds(CanvasLayer l, Rect b, LayerAlignment a) =>
      switch (a) {
        LayerAlignment.left => l.copyWithGeometry(x: b.left),
        LayerAlignment.hCenter => l.copyWithGeometry(x: b.center.dx - l.width / 2),
        LayerAlignment.right => l.copyWithGeometry(x: b.right - l.width),
        LayerAlignment.top => l.copyWithGeometry(y: b.top),
        LayerAlignment.vCenter => l.copyWithGeometry(y: b.center.dy - l.height / 2),
        LayerAlignment.bottom => l.copyWithGeometry(y: b.bottom - l.height),
      };

  /// Distributes 3+ selected layers so their CENTRES are evenly spaced between
  /// the first and last along [axis].
  void distributeSelected(DistributeAxis axis) {
    final sels = _selectedLayers;
    if (sels.length < 3) return;
    final horizontal = axis == DistributeAxis.horizontal;
    final sorted = [...sels]..sort((a, b) => horizontal
        ? a.center.dx.compareTo(b.center.dx)
        : a.center.dy.compareTo(b.center.dy),);
    final firstC = horizontal ? sorted.first.center.dx : sorted.first.center.dy;
    final lastC = horizontal ? sorted.last.center.dx : sorted.last.center.dy;
    final step = (lastC - firstC) / (sorted.length - 1);

    final moves = <String, CanvasLayer>{};
    for (var i = 1; i < sorted.length - 1; i++) {
      final l = sorted[i];
      if (l.locked) continue;
      final targetCenter = firstC + step * i;
      moves[l.id] = horizontal
          ? l.copyWithGeometry(x: targetCenter - l.width / 2)
          : l.copyWithGeometry(y: targetCenter - l.height / 2);
    }
    if (moves.isEmpty) return;
    final updated = [
      for (final layer in state.document.layers) moves[layer.id] ?? layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

  /// Matches the width (or height) of all selected layers to the largest among
  /// them (needs 2+).
  void matchSelectedSize({required bool width}) {
    final sels = _selectedLayers;
    if (sels.length < 2) return;
    final target = width
        ? sels.map((l) => l.width).reduce(math.max)
        : sels.map((l) => l.height).reduce(math.max);
    final ids = state.selectedLayerIds;
    final updated = [
      for (final layer in state.document.layers)
        if (ids.contains(layer.id) && !layer.locked)
          (width
              ? layer.copyWithGeometry(width: target)
              : layer.copyWithGeometry(height: target))
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), ids);
  }

  Rect _boundsOf(List<CanvasLayer> layers) {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (final layer in layers) {
      l = math.min(l, layer.x);
      t = math.min(t, layer.y);
      r = math.max(r, layer.x + layer.width);
      b = math.max(b, layer.y + layer.height);
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  // ---- Colour / text / shape / video (single) ---------------------------

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
    _applyDocument(state.document.copyWithLayers(updatedLayers), state.selectedLayerIds);
  }

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
    _applyDocument(state.document.copyWithLayers(updatedLayers), state.selectedLayerIds);
  }

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
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

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
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

  void updateSelectedTextFormat({
    bool? bold,
    bool? italic,
    TextAlign? align,
    double? lineHeight,
    double? letterSpacing,
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
            letterSpacing: letterSpacing,
          )
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

  /// Highlight background / text outline on the selected text layer.
  void updateSelectedTextDecoration({
    Color? highlightColor,
    bool clearHighlight = false,
    Color? strokeColor,
    bool clearStroke = false,
    double? strokeWidth,
  }) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id && layer is TextCanvasLayer)
          layer.copyWithTextDecoration(
            highlightColor: highlightColor,
            clearHighlight: clearHighlight,
            strokeColor: strokeColor,
            clearStroke: clearStroke,
            strokeWidth: strokeWidth,
          )
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

  /// Rewrites the selected text layer's content to UPPER / lower / Title case.
  void transformSelectedTextCase(TextCase mode) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id && layer is TextCanvasLayer)
          layer.copyWithText(_applyCase(layer.text, mode))
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

  String _applyCase(String text, TextCase mode) {
    switch (mode) {
      case TextCase.upper:
        return text.toUpperCase();
      case TextCase.lower:
        return text.toLowerCase();
      case TextCase.title:
        // Title-case each run of non-space chars, preserving all whitespace.
        return text.replaceAllMapped(RegExp(r'\S+'), (m) {
          final w = m[0]!;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        });
    }
  }

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
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

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
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

  // ---- Canvas-level ------------------------------------------------------

  void setBackgroundColor(Color color) {
    _applyDocument(
      state.document.copyWith(backgroundColor: color),
      state.selectedLayerIds,
    );
  }

  void resizeArtboard(double width, double height) {
    if (width <= 0 || height <= 0) return;
    _applyDocument(
      state.document.copyWith(width: width, height: height),
      state.selectedLayerIds,
    );
  }

  void setLayerLocked(String id, bool locked) => _setFlags(id, locked: locked);
  void setLayerHidden(String id, bool hidden) => _setFlags(id, hidden: hidden);

  void _setFlags(String id, {bool? locked, bool? hidden}) {
    final updated = [
      for (final layer in state.document.layers)
        if (layer.id == id)
          layer.copyWithFlags(locked: locked, hidden: hidden)
        else
          layer,
    ];
    _applyDocument(state.document.copyWithLayers(updated), state.selectedLayerIds);
  }

  // ---- Add / delete / duplicate / clipboard -----------------------------

  void addLayer(CanvasLayer layer) {
    _applyDocument(
      state.document.copyWithLayers([...state.document.layers, layer]),
      {layer.id},
    );
  }

  /// Deletes every selected layer and clears selection. No-op when nothing is
  /// selected.
  void deleteSelectedLayer() {
    final ids = state.selectedLayerIds;
    if (ids.isEmpty) return;
    final remaining =
        state.document.layers.where((l) => !ids.contains(l.id)).toList();
    if (remaining.length == state.document.layers.length) return;
    _applyDocument(state.document.copyWithLayers(remaining), const {});
  }

  /// Duplicates the selected layer(s) — each an offset copy — and selects the
  /// copies. A single selection inserts its copy directly above the original
  /// (the classic behaviour); a multi selection appends the copies on top.
  void duplicateSelectedLayer() {
    final sels = _selectedLayers;
    if (sels.isEmpty) return;
    final layers = [...state.document.layers];
    final newIds = <String>{};
    if (sels.length == 1) {
      final original = sels.first;
      final copy = _cloneWithOffset(original, _nextId(), const Offset(20, 20));
      final index = layers.indexWhere((l) => l.id == original.id);
      layers.insert(index + 1, copy);
      newIds.add(copy.id);
    } else {
      for (final l in sels) {
        final copy = _cloneWithOffset(l, _nextId(), const Offset(20, 20));
        layers.add(copy);
        newIds.add(copy.id);
      }
    }
    _applyDocument(state.document.copyWithLayers(layers), newIds);
  }

  void bringSelectedForward() => _reorderSelected(1);
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
    _applyDocument(state.document.copyWithLayers(layers), {id});
  }

  void bringSelectedToFront() => _reorderSelectedTo(true);
  void sendSelectedToBack() => _reorderSelectedTo(false);

  void _reorderSelectedTo(bool front) {
    final id = state.selectedLayerId;
    if (id == null) return;
    final layers = [...state.document.layers];
    final i = layers.indexWhere((l) => l.id == id);
    if (i < 0) return;
    if (front && i == layers.length - 1) return;
    if (!front && i == 0) return;
    final moved = layers.removeAt(i);
    front ? layers.add(moved) : layers.insert(0, moved);
    _applyDocument(state.document.copyWithLayers(layers), {id});
  }

  /// Session clipboard — the last copied (or cut) layers.
  List<CanvasLayer> _clipboard = const [];
  bool get hasClipboard => _clipboard.isNotEmpty;

  void copySelectedLayer() {
    final sels = _selectedLayers;
    if (sels.isNotEmpty) _clipboard = sels;
  }

  void cutSelectedLayer() {
    final sels = _selectedLayers;
    if (sels.isEmpty) return;
    _clipboard = sels;
    deleteSelectedLayer();
  }

  /// Pastes the clipboard layer(s) as offset copies on top, and selects them.
  void pasteLayer() {
    if (_clipboard.isEmpty) return;
    final layers = [...state.document.layers];
    final newIds = <String>{};
    for (final source in _clipboard) {
      final copy = _cloneWithOffset(source, _nextId(), const Offset(20, 20));
      layers.add(copy);
      newIds.add(copy.id);
    }
    _applyDocument(state.document.copyWithLayers(layers), newIds);
  }

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
          letterSpacing: t.letterSpacing,
          highlightColor: t.highlightColor,
          strokeColor: t.strokeColor,
          strokeWidth: t.strokeWidth,
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

  /// Replaces the whole document in one undoable edit (e.g. apply brand kit),
  /// clearing selection since layers may have been restyled out from under it.
  void replaceDocument(CanvasDocument document) =>
      _applyDocument(document, const {});

  void undo() {
    final restored = _history.undo(state.document);
    if (restored == null) return;
    _emit(restored, const {});
  }

  void redo() {
    final restored = _history.redo(state.document);
    if (restored == null) return;
    _emit(restored, const {});
  }

  /// The single write path for document *edits*. Records history (once per
  /// discrete edit, or once per continuous gesture) then emits.
  void _applyDocument(CanvasDocument document, Set<String> selectedLayerIds) {
    if (!_interactionActive) {
      _history.record(state.document);
    } else if (!_interactionRecorded) {
      _history.record(state.document);
      _interactionRecorded = true;
    }
    _emit(document, selectedLayerIds);
  }

  void _emit(CanvasDocument document, Set<String> selectedLayerIds) {
    state = CanvasEditorState(
      document: document,
      selectedLayerIds: selectedLayerIds,
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

  List<CanvasLayer> get _selectedLayers => [
        for (final layer in state.document.layers)
          if (state.selectedLayerIds.contains(layer.id)) layer,
      ];
}

final canvasControllerProvider = StateNotifierProvider.autoDispose
    .family<CanvasController, CanvasEditorState, CanvasDocument>(
  (ref, initialDocument) => CanvasController(initialDocument),
);
