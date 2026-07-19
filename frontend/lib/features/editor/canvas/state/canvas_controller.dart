import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hit_testing.dart';
import '../models/canvas_document.dart';
import 'canvas_editor_state.dart';

/// Selection + drag logic for one editor session. Deliberately NOT a
/// singleton provider (unlike e.g. authControllerProvider) — a
/// StateNotifierProvider.family.autoDispose instance is created per
/// initial CanvasDocument, matching how a future EditorScreen(assetId)
/// will use it: `ref.watch(canvasControllerProvider(loadedDocument))`.
/// autoDispose so state is cleaned up once nothing is watching it
/// (i.e., once the editor screen is left).
///
/// SCOPE NOTE (Milestone 3.3): select + move only. Undo/redo is
/// Milestone 3.5's job — deliberately not attempted here, so there's no
/// half-built history stack to get subtly wrong before that milestone
/// actually needs one.
class CanvasController extends StateNotifier<CanvasEditorState> {
  CanvasController(CanvasDocument initialDocument)
      : super(CanvasEditorState(document: initialDocument));

  /// Hit-tests `artboardPoint` against the current layer stack and
  /// selects whatever's on top there, or clears selection if nothing is.
  void selectLayerAt(Offset artboardPoint) {
    final hit = hitTestLayers(state.document.layers, artboardPoint);
    state = CanvasEditorState(document: state.document, selectedLayerId: hit?.id);
  }

  void clearSelection() {
    state = CanvasEditorState(document: state.document, selectedLayerId: null);
  }

  /// Moves the currently-selected layer by `delta` (artboard-space
  /// units, already converted from screen pixels by the caller — see
  /// CanvasSurface). No-ops if nothing is selected, rather than throwing
  /// — a drag gesture starting on empty canvas is a normal, expected
  /// interaction, not an error condition.
  void moveSelectedLayerBy(Offset delta) {
    final selectedId = state.selectedLayerId;
    if (selectedId == null) return;

    final updatedLayers = [
      for (final layer in state.document.layers)
        if (layer.id == selectedId)
          layer.copyWithPosition(layer.x + delta.dx, layer.y + delta.dy)
        else
          layer,
    ];

    state = CanvasEditorState(
      document: state.document.copyWithLayers(updatedLayers),
      selectedLayerId: selectedId,
    );
  }
}

final canvasControllerProvider = StateNotifierProvider.autoDispose
    .family<CanvasController, CanvasEditorState, CanvasDocument>(
  (ref, initialDocument) => CanvasController(initialDocument),
);
