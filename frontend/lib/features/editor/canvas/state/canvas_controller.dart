import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// SCOPE NOTE (Milestone 3.3/3.4): select, drag, and direct property
/// editing (position/size/rotation/color) only. Undo/redo is Milestone
/// 3.5's job — deliberately not attempted here, so there's no half-built
/// history stack to get subtly wrong before that milestone actually
/// needs one.
class CanvasController extends StateNotifier<CanvasEditorState> {
  CanvasController(CanvasDocument initialDocument)
      : super(CanvasEditorState(document: initialDocument));

  /// Hit-tests `artboardPoint` against the current layer stack and
  /// selects whatever's on top there, or clears selection if nothing is.
  /// Used by CanvasSurface's gesture handling (a tap/drag-start position
  /// on the canvas itself).
  void selectLayerAt(Offset artboardPoint) {
    final hit = hitTestLayers(state.document.layers, artboardPoint);
    state = CanvasEditorState(document: state.document, selectedLayerId: hit?.id);
  }

  /// Selects by id directly — used by the layer panel (Milestone 3.4),
  /// where the user clicks a list row rather than a canvas position.
  /// Pass null to clear selection.
  void selectLayerById(String? layerId) {
    state = CanvasEditorState(document: state.document, selectedLayerId: layerId);
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

    state = CanvasEditorState(
      document: state.document.copyWithLayers(updatedLayers),
      selectedLayerId: selectedId,
    );
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
          }
        else
          layer,
    ];

    state = CanvasEditorState(
      document: state.document.copyWithLayers(updatedLayers),
      selectedLayerId: selectedId,
    );
  }

  /// Adds a new layer to the top of the stack and selects it — used by
  /// the toolbar's "add shape/text" actions (Milestone 3.4).
  void addLayer(CanvasLayer layer) {
    state = CanvasEditorState(
      document: state.document.copyWithLayers([...state.document.layers, layer]),
      selectedLayerId: layer.id,
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
