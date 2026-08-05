import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_document.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';
import 'package:socialhub/features/editor/canvas/state/canvas_controller.dart';

/// Undo/redo behaviour of CanvasController (Milestone 3.5) — the
/// integration between the pure EditorHistory stack and real canvas
/// edits. The stack's own semantics are covered separately in
/// test/unit/features/editor/state/history_controller_test.dart.
void main() {
  group('CanvasController undo/redo', () {
    late CanvasDocument document;

    setUp(() {
      document = const CanvasDocument(
        width: 1080,
        height: 1080,
        layers: [
          ShapeCanvasLayer(
            id: 'layer_a',
            x: 0,
            y: 0,
            width: 100,
            height: 100,
            shapeKind: ShapeKind.rectangle,
          ),
        ],
      );
    });

    test('a fresh controller has nothing to undo or redo', () {
      final controller = CanvasController(document);
      expect(controller.state.canUndo, isFalse);
      expect(controller.state.canRedo, isFalse);
    });

    test('undo reverts a geometry edit', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.updateSelectedLayerGeometry(width: 500);

      expect(controller.state.document.layers.single.width, 500);
      expect(controller.state.canUndo, isTrue);

      controller.undo();
      expect(controller.state.document.layers.single.width, 100);
    });

    test('redo re-applies an undone edit', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.updateSelectedLayerGeometry(width: 500);
      controller.undo();

      expect(controller.state.canRedo, isTrue);
      controller.redo();
      expect(controller.state.document.layers.single.width, 500);
    });

    test('undo reverts an addLayer, removing the layer again', () {
      final controller = CanvasController(document);
      controller.addLayer(
        const ShapeCanvasLayer(
          id: 'layer_b',
          x: 0,
          y: 0,
          width: 10,
          height: 10,
          shapeKind: ShapeKind.ellipse,
        ),
      );
      expect(controller.state.document.layers.length, 2);

      controller.undo();
      expect(controller.state.document.layers.length, 1);
      expect(controller.state.document.layers.single.id, 'layer_a');
    });

    test('undo reverts a color change', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.updateSelectedLayerColor(const Color(0xFFFF0000));

      controller.undo();
      final layer = controller.state.document.layers.single as ShapeCanvasLayer;
      expect(layer.fillColor, const Color(0xFF3B82F6)); // the default
    });

    test('selection changes are NOT undoable steps', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.clearSelection();
      controller.selectLayerById('layer_a');

      expect(
        controller.state.canUndo,
        isFalse,
        reason: 'clicking around a design is not an edit',
      );
    });

    test('undo on a fresh document is a harmless no-op', () {
      final controller = CanvasController(document);
      expect(controller.undo, returnsNormally);
      expect(controller.state.document.layers.single.width, 100);
    });

    test('a bracketed drag collapses into exactly ONE undo step', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');

      // Simulates CanvasSurface: onPanStart → many onPanUpdate → onPanEnd.
      controller.beginInteraction();
      for (var i = 0; i < 50; i++) {
        controller.moveSelectedLayerBy(const Offset(1, 1));
      }
      controller.endInteraction();

      expect(controller.state.document.layers.single.x, 50);

      controller.undo();
      expect(
        controller.state.document.layers.single.x,
        0,
        reason: 'one Ctrl+Z should undo the whole drag, not one pixel of it',
      );
      expect(controller.state.canUndo, isFalse);
    });

    test('two successive drags are two separate undo steps', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');

      controller.beginInteraction();
      controller.moveSelectedLayerBy(const Offset(10, 0));
      controller.moveSelectedLayerBy(const Offset(10, 0));
      controller.endInteraction();

      controller.selectLayerById('layer_a');
      controller.beginInteraction();
      controller.moveSelectedLayerBy(const Offset(5, 0));
      controller.endInteraction();

      expect(controller.state.document.layers.single.x, 25);

      controller.undo(); // undoes only the second drag
      expect(controller.state.document.layers.single.x, 20);

      controller.selectLayerById('layer_a');
      controller.undo(); // undoes the first
      expect(controller.state.document.layers.single.x, 0);
    });

    test('a new edit after an undo discards the redo branch', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.updateSelectedLayerGeometry(width: 500);
      controller.undo();
      expect(controller.state.canRedo, isTrue);

      controller.selectLayerById('layer_a');
      controller.updateSelectedLayerGeometry(height: 700);
      expect(controller.state.canRedo, isFalse);
    });

    test('undo clears selection, so no panel points at a removed layer', () {
      final controller = CanvasController(document);
      controller.addLayer(
        const ShapeCanvasLayer(
          id: 'layer_b',
          x: 0,
          y: 0,
          width: 10,
          height: 10,
          shapeKind: ShapeKind.ellipse,
        ),
      );
      expect(controller.state.selectedLayerId, 'layer_b');

      controller.undo();
      expect(controller.state.selectedLayerId, isNull);
    });
  });
}
