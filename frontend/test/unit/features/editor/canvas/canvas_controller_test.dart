import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_document.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';
import 'package:socialhub/features/editor/canvas/state/canvas_controller.dart';

void main() {
  group('CanvasController', () {
    late CanvasDocument document;

    setUp(() {
      document = CanvasDocument(
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
          ShapeCanvasLayer(
            id: 'layer_b',
            x: 500,
            y: 500,
            width: 100,
            height: 100,
            shapeKind: ShapeKind.rectangle,
          ),
        ],
      );
    });

    test('initial state has no selection', () {
      final controller = CanvasController(document);
      expect(controller.state.selectedLayerId, isNull);
    });

    test('selectLayerAt selects the layer under the point', () {
      final controller = CanvasController(document);
      controller.selectLayerAt(const Offset(50, 50)); // inside layer_a
      expect(controller.state.selectedLayerId, 'layer_a');
    });

    test('selectLayerAt clears selection when the point hits nothing', () {
      final controller = CanvasController(document);
      controller.selectLayerAt(const Offset(50, 50));
      expect(controller.state.selectedLayerId, 'layer_a');

      controller.selectLayerAt(const Offset(900, 900)); // empty area
      expect(controller.state.selectedLayerId, isNull);
    });

    test('clearSelection removes selection without touching the document', () {
      final controller = CanvasController(document);
      controller.selectLayerAt(const Offset(50, 50));
      controller.clearSelection();

      expect(controller.state.selectedLayerId, isNull);
      expect(controller.state.document.layers.length, 2);
    });

    test('moveSelectedLayerBy is a no-op when nothing is selected', () {
      final controller = CanvasController(document);
      controller.moveSelectedLayerBy(const Offset(10, 10));

      final layerA = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(layerA.x, 0); // unchanged
      expect(layerA.y, 0);
    });

    test('moveSelectedLayerBy moves ONLY the selected layer, by exactly the given delta', () {
      final controller = CanvasController(document);
      controller.selectLayerAt(const Offset(50, 50)); // selects layer_a
      controller.moveSelectedLayerBy(const Offset(15, -5));

      final layerA = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      final layerB = controller.state.document.layers.firstWhere((l) => l.id == 'layer_b');

      expect(layerA.x, 15);
      expect(layerA.y, -5);
      // layer_b must be completely untouched.
      expect(layerB.x, 500);
      expect(layerB.y, 500);
    });

    test('moveSelectedLayerBy accumulates across multiple calls (simulating a drag)', () {
      final controller = CanvasController(document);
      controller.selectLayerAt(const Offset(50, 50));
      controller.moveSelectedLayerBy(const Offset(10, 0));
      controller.moveSelectedLayerBy(const Offset(10, 0));
      controller.moveSelectedLayerBy(const Offset(5, 3));

      final layerA = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(layerA.x, 25);
      expect(layerA.y, 3);
    });

    test('selection survives a move (still selected after being dragged)', () {
      final controller = CanvasController(document);
      controller.selectLayerAt(const Offset(50, 50));
      controller.moveSelectedLayerBy(const Offset(500, 500)); // drag layer_a on top of layer_b's original spot

      expect(controller.state.selectedLayerId, 'layer_a');
    });
  });
}
