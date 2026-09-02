import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_document.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';
import 'package:socialhub/features/editor/canvas/state/canvas_controller.dart';

void main() {
  group('CanvasController', () {
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

    test('selectLayerById selects directly by id, without needing a canvas point', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_b');
      expect(controller.state.selectedLayerId, 'layer_b');
    });

    test('selectLayerById(null) clears selection, same as clearSelection', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.selectLayerById(null);
      expect(controller.state.selectedLayerId, isNull);
    });

    test('updateSelectedLayerGeometry is a no-op when nothing is selected', () {
      final controller = CanvasController(document);
      controller.updateSelectedLayerGeometry(width: 999);

      final layerA = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(layerA.width, 100); // unchanged
    });

    test('updateSelectedLayerGeometry updates only the fields passed, on only the selected layer', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.updateSelectedLayerGeometry(width: 300, rotationDegrees: 45);

      final layerA = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      final layerB = controller.state.document.layers.firstWhere((l) => l.id == 'layer_b');

      expect(layerA.width, 300);
      expect(layerA.rotationDegrees, 45);
      expect(layerA.x, 0); // untouched — wasn't passed
      expect(layerA.height, 100); // untouched — wasn't passed
      // layer_b completely untouched.
      expect(layerB.width, 100);
      expect(layerB.rotationDegrees, 0);
    });

    test('updateSelectedLayerColor sets fill color on a selected ShapeCanvasLayer', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.updateSelectedLayerColor(const Color(0xFFFF00FF));

      final layerA = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a')
          as ShapeCanvasLayer;
      expect(layerA.fillColor, const Color(0xFFFF00FF));
    });

    test('updateSelectedLayerColor sets text color on a selected TextCanvasLayer', () {
      final withText = document.copyWithLayers([
        ...document.layers,
        const TextCanvasLayer(id: 'text_a', x: 200, y: 200, width: 100, height: 30, text: 'Hi'),
      ]);
      final controller = CanvasController(withText);
      controller.selectLayerById('text_a');
      controller.updateSelectedLayerColor(const Color(0xFF123456));

      final textLayer =
          controller.state.document.layers.firstWhere((l) => l.id == 'text_a') as TextCanvasLayer;
      expect(textLayer.color, const Color(0xFF123456));
    });

    test('updateSelectedLayerColor is a safe no-op on a selected ImageCanvasLayer', () {
      final withImage = document.copyWithLayers([
        ...document.layers,
        const ImageCanvasLayer(
          id: 'img_a',
          x: 300,
          y: 300,
          width: 100,
          height: 100,
          imageUrl: 'https://example.com/a.jpg',
        ),
      ]);
      final controller = CanvasController(withImage);
      controller.selectLayerById('img_a');

      expect(
        () => controller.updateSelectedLayerColor(const Color(0xFFABCDEF)),
        returnsNormally,
      );
      final imageLayer =
          controller.state.document.layers.firstWhere((l) => l.id == 'img_a') as ImageCanvasLayer;
      expect(imageLayer.imageUrl, 'https://example.com/a.jpg'); // still intact
    });

    test('addLayer appends to the stack and selects the new layer', () {
      final controller = CanvasController(document);
      const newLayer = ShapeCanvasLayer(
        id: 'layer_c',
        x: 10,
        y: 10,
        width: 50,
        height: 50,
        shapeKind: ShapeKind.ellipse,
      );

      controller.addLayer(newLayer);

      expect(controller.state.document.layers.length, 3);
      expect(controller.state.document.layers.last.id, 'layer_c');
      expect(controller.state.selectedLayerId, 'layer_c');
    });

    test('deleteSelectedLayer removes it and clears selection', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.deleteSelectedLayer();

      expect(controller.state.document.layers.map((l) => l.id), ['layer_b']);
      expect(controller.state.selectedLayerId, isNull);
    });

    test('deleteSelectedLayer no-ops when nothing is selected', () {
      final controller = CanvasController(document);
      controller.deleteSelectedLayer();
      expect(controller.state.document.layers.length, 2);
    });

    test('duplicateSelectedLayer inserts an offset copy above and selects it',
        () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.duplicateSelectedLayer();

      final layers = controller.state.document.layers;
      expect(layers.length, 3);
      // Copy sits directly above the original.
      expect(layers[0].id, 'layer_a');
      final copy = layers[1];
      expect(copy.id, isNot('layer_a'));
      expect(copy.id, controller.state.selectedLayerId);
      expect(copy.x, 20); // original x 0 + 20 offset
      expect(copy.y, 20);
    });

    test('bringSelectedForward / sendSelectedBackward reorder the stack', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a'); // index 0 (bottom)
      controller.bringSelectedForward();
      expect(controller.state.document.layers.map((l) => l.id), [
        'layer_b',
        'layer_a',
      ]);
      controller.sendSelectedBackward();
      expect(controller.state.document.layers.map((l) => l.id), [
        'layer_a',
        'layer_b',
      ]);
    });

    test('reorder no-ops at the edges of the stack', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a'); // already at the bottom
      controller.sendSelectedBackward();
      expect(controller.state.document.layers.map((l) => l.id), [
        'layer_a',
        'layer_b',
      ]);
    });

    test('text + font size edits apply only to a selected text layer', () {
      final controller = CanvasController(
        const CanvasDocument(
          width: 1080,
          height: 1080,
          layers: [
            TextCanvasLayer(
              id: 'txt',
              x: 0,
              y: 0,
              width: 200,
              height: 40,
              text: 'old',
            ),
          ],
        ),
      );
      controller.selectLayerById('txt');
      controller.updateSelectedLayerText('new copy');
      controller.updateSelectedTextFontSize(48);

      final layer = controller.state.document.layers.single as TextCanvasLayer;
      expect(layer.text, 'new copy');
      expect(layer.fontSize, 48);
    });

    test('all edits are undoable', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.deleteSelectedLayer();
      expect(controller.state.document.layers.length, 1);
      controller.undo();
      expect(controller.state.document.layers.length, 2);
    });

    test('setBackgroundColor changes the artboard background (undoable)', () {
      final controller = CanvasController(document);
      controller.setBackgroundColor(const Color(0xFF0D0F14));
      expect(controller.state.document.backgroundColor, const Color(0xFF0D0F14));
      controller.undo();
      expect(controller.state.document.backgroundColor, const Color(0xFFFFFFFF));
    });

    test('resizeArtboard changes size but keeps layers; ignores non-positive', () {
      final controller = CanvasController(document);
      controller.resizeArtboard(1080, 1920);
      expect(controller.state.document.width, 1080);
      expect(controller.state.document.height, 1920);
      expect(controller.state.document.layers.length, 2);
      controller.resizeArtboard(0, 500); // ignored
      expect(controller.state.document.width, 1080);
    });

    test('alignSelectedToArtboard centres and edges the selected layer', () {
      final controller = CanvasController(document); // 1080x1080, layer_a 100x100
      controller.selectLayerById('layer_a');

      controller.alignSelectedToArtboard(LayerAlignment.hCenter);
      var a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.x, (1080 - 100) / 2);

      controller.alignSelectedToArtboard(LayerAlignment.right);
      a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.x, 1080 - 100);

      controller.alignSelectedToArtboard(LayerAlignment.bottom);
      a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.y, 1080 - 100);
    });

    test('lock/hide toggle by id; a locked layer will not move or nudge', () {
      final controller = CanvasController(document);
      controller.setLayerLocked('layer_a', true);
      controller.setLayerHidden('layer_b', true);
      final a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      final b = controller.state.document.layers.firstWhere((l) => l.id == 'layer_b');
      expect(a.locked, isTrue);
      expect(b.hidden, isTrue);

      controller.selectLayerById('layer_a');
      controller.nudgeSelected(10, 10); // locked → no-op
      final aAfter = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(aAfter.x, 0);
    });

    test('nudgeSelected moves an unlocked selection', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_b'); // at (500,500)
      controller.nudgeSelected(-10, 5);
      final b = controller.state.document.layers.firstWhere((l) => l.id == 'layer_b');
      expect(b.x, 490);
      expect(b.y, 505);
    });

    test('text format + font family edits apply to the selected text layer', () {
      final controller = CanvasController(
        const CanvasDocument(
          width: 1080,
          height: 1080,
          layers: [
            TextCanvasLayer(id: 'txt', x: 0, y: 0, width: 200, height: 40, text: 'hi'),
          ],
        ),
      );
      controller.selectLayerById('txt');
      controller.updateSelectedTextFormat(
        bold: true,
        italic: true,
        align: TextAlign.center,
        lineHeight: 1.5,
      );
      controller.updateSelectedTextFontFamily('Roboto');

      final t = controller.state.document.layers.single as TextCanvasLayer;
      expect(t.bold, isTrue);
      expect(t.italic, isTrue);
      expect(t.align, TextAlign.center);
      expect(t.lineHeight, 1.5);
      expect(t.fontFamily, 'Roboto');
    });

    test('toggleLayerSelection builds a multi-selection', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.toggleLayerSelection('layer_b');
      expect(controller.state.selectedLayerIds, {'layer_a', 'layer_b'});
      expect(controller.state.selectedLayerId, isNull); // ambiguous when >1
      controller.toggleLayerSelection('layer_a');
      expect(controller.state.selectedLayerIds, {'layer_b'});
    });

    test('selectLayersInRect selects the layers a marquee overlaps', () {
      final controller = CanvasController(document);
      controller.selectLayersInRect(const Rect.fromLTWH(0, 0, 600, 600));
      expect(controller.state.selectedLayerIds, {'layer_a', 'layer_b'});
      controller.selectLayersInRect(const Rect.fromLTWH(0, 0, 50, 50));
      expect(controller.state.selectedLayerIds, {'layer_a'}); // only a overlaps
    });

    test('moveSelectedLayerBy moves EVERY selected layer', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.toggleLayerSelection('layer_b');
      controller.moveSelectedLayerBy(const Offset(10, 20));
      final a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      final b = controller.state.document.layers.firstWhere((l) => l.id == 'layer_b');
      expect(a.x, 10);
      expect(a.y, 20);
      expect(b.x, 510);
      expect(b.y, 520);
    });

    test('alignSelectedToSelection aligns selected layers to their bbox', () {
      final controller = CanvasController(document); // a@x0, b@x500
      controller.selectLayerById('layer_a');
      controller.toggleLayerSelection('layer_b');
      controller.alignSelectedToSelection(LayerAlignment.left);
      final a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      final b = controller.state.document.layers.firstWhere((l) => l.id == 'layer_b');
      expect(a.x, 0);
      expect(b.x, 0); // pulled to the selection's left edge
    });

    test('distributeSelected evenly spaces 3+ centres', () {
      final controller = CanvasController(
        const CanvasDocument(
          width: 1000,
          height: 100,
          layers: [
            ShapeCanvasLayer(id: 'l', x: 0, y: 0, width: 10, height: 10, shapeKind: ShapeKind.rectangle),
            ShapeCanvasLayer(id: 'm', x: 100, y: 0, width: 10, height: 10, shapeKind: ShapeKind.rectangle),
            ShapeCanvasLayer(id: 'r', x: 900, y: 0, width: 10, height: 10, shapeKind: ShapeKind.rectangle),
          ],
        ),
      );
      controller.selectLayersInRect(const Rect.fromLTWH(0, 0, 1000, 100));
      controller.distributeSelected(DistributeAxis.horizontal);
      // first centre 5, last centre 905 → middle centre should be 455 → x=450.
      final m = controller.state.document.layers.firstWhere((l) => l.id == 'm');
      expect(m.x, 450);
    });

    test('matchSelectedSize sets all selected to the largest dimension', () {
      final controller = CanvasController(
        const CanvasDocument(
          width: 1000,
          height: 1000,
          layers: [
            ShapeCanvasLayer(id: 's', x: 0, y: 0, width: 40, height: 40, shapeKind: ShapeKind.rectangle),
            ShapeCanvasLayer(id: 'big', x: 0, y: 0, width: 200, height: 80, shapeKind: ShapeKind.rectangle),
          ],
        ),
      );
      controller.selectLayersInRect(const Rect.fromLTWH(0, 0, 1000, 1000));
      controller.matchSelectedSize(width: true);
      final s = controller.state.document.layers.firstWhere((l) => l.id == 's');
      expect(s.width, 200); // matched to the largest width
    });

    test('multi delete removes every selected layer', () {
      final controller = CanvasController(document);
      controller.selectLayersInRect(const Rect.fromLTWH(0, 0, 600, 600));
      controller.deleteSelectedLayer();
      expect(controller.state.document.layers, isEmpty);
    });

    test('flipSelected toggles the horizontal/vertical mirror flags', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.flipSelected(horizontal: true);
      var a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.flipH, isTrue);
      expect(a.flipV, isFalse);
      controller.flipSelected(horizontal: true);
      a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.flipH, isFalse);
      controller.flipSelected(horizontal: false);
      a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.flipV, isTrue);
    });

    test('resizeSelectedByHandle keeps the opposite edge fixed', () {
      final controller = CanvasController(document); // layer_a at (0,0) 100x100
      controller.selectLayerById('layer_a');

      // East handle: grows width, left edge (x) stays put.
      controller.resizeSelectedByHandle(ResizeHandle.e, const Offset(50, 0));
      var a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.x, 0);
      expect(a.width, 150);
      expect(a.height, 100);

      // NW handle on the (now 150x100) layer: right & bottom edges stay fixed.
      controller.resizeSelectedByHandle(ResizeHandle.nw, const Offset(-10, -20));
      a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.width, 160); // 150 - (-10)
      expect(a.height, 120); // 100 - (-20)
      expect(a.x, -10); // rightEdge(150) - 160
      expect(a.y, -20); // bottomEdge(100) - 120
    });

    test('resizeSelectedByHandle: aspect lock on a corner, and min-size clamp', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a'); // 100x100

      controller.resizeSelectedByHandle(
        ResizeHandle.se,
        const Offset(50, 0),
        lockAspect: true,
      );
      var a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.width, 150);
      expect(a.height, 150); // derived from the 1:1 ratio

      // Shrink far past zero → clamps to the 8px minimum.
      controller.resizeSelectedByHandle(ResizeHandle.e, const Offset(-1000, 0));
      a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a');
      expect(a.width, 8);
    });

    test('duplicate preserves the flip flags', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.flipSelected(horizontal: true);
      controller.duplicateSelectedLayer();
      final copy = controller.state.document.layers[1];
      expect(copy.flipH, isTrue);
    });

    test('bringSelectedToFront / sendSelectedToBack jump to the stack ends', () {
      final controller = CanvasController(
        const CanvasDocument(
          width: 100,
          height: 100,
          layers: [
            ShapeCanvasLayer(id: 'a', x: 0, y: 0, width: 1, height: 1, shapeKind: ShapeKind.rectangle),
            ShapeCanvasLayer(id: 'b', x: 0, y: 0, width: 1, height: 1, shapeKind: ShapeKind.rectangle),
            ShapeCanvasLayer(id: 'c', x: 0, y: 0, width: 1, height: 1, shapeKind: ShapeKind.rectangle),
          ],
        ),
      );
      controller.selectLayerById('a'); // bottom
      controller.bringSelectedToFront();
      expect(controller.state.document.layers.map((l) => l.id), ['b', 'c', 'a']);
      controller.sendSelectedToBack();
      expect(controller.state.document.layers.map((l) => l.id), ['a', 'b', 'c']);
    });

    test('copy + paste inserts an offset copy on top and selects it', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a'); // (0,0)
      controller.copySelectedLayer();
      controller.pasteLayer();

      final layers = controller.state.document.layers;
      expect(layers.length, 3);
      final pasted = layers.last;
      expect(pasted.id, isNot('layer_a'));
      expect(pasted.id, controller.state.selectedLayerId);
      expect(pasted.x, 20); // offset from the copied (0,0)
      expect(pasted.y, 20);
    });

    test('cut removes the layer but keeps it on the clipboard for paste', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.cutSelectedLayer();
      expect(controller.state.document.layers.map((l) => l.id), ['layer_b']);
      expect(controller.hasClipboard, isTrue);
      controller.pasteLayer();
      expect(controller.state.document.layers.length, 2);
    });

    test('paste is a no-op when the clipboard is empty', () {
      final controller = CanvasController(document);
      controller.pasteLayer();
      expect(controller.state.document.layers.length, 2);
    });

    TextCanvasLayer textDoc(String text) => TextCanvasLayer(
          id: 'txt',
          x: 0,
          y: 0,
          width: 200,
          height: 40,
          text: text,
        );

    test('letter spacing applies to the selected text layer', () {
      final controller = CanvasController(
        CanvasDocument(width: 1080, height: 1080, layers: [textDoc('hi')]),
      );
      controller.selectLayerById('txt');
      controller.updateSelectedTextFormat(letterSpacing: 5);
      final t = controller.state.document.layers.single as TextCanvasLayer;
      expect(t.letterSpacing, 5);
    });

    test('text case transform rewrites the content', () {
      final controller = CanvasController(
        CanvasDocument(width: 1080, height: 1080, layers: [textDoc('hello world')]),
      );
      controller.selectLayerById('txt');
      controller.transformSelectedTextCase(TextCase.upper);
      expect((controller.state.document.layers.single as TextCanvasLayer).text,
          'HELLO WORLD',);
      controller.transformSelectedTextCase(TextCase.title);
      expect((controller.state.document.layers.single as TextCanvasLayer).text,
          'Hello World',);
      controller.transformSelectedTextCase(TextCase.lower);
      expect((controller.state.document.layers.single as TextCanvasLayer).text,
          'hello world',);
    });

    test('text decoration sets/clears highlight and outline', () {
      final controller = CanvasController(
        CanvasDocument(width: 1080, height: 1080, layers: [textDoc('hi')]),
      );
      controller.selectLayerById('txt');
      controller.updateSelectedTextDecoration(
        highlightColor: const Color(0xFFFFFF00),
        strokeColor: const Color(0xFF000000),
        strokeWidth: 2,
      );
      var t = controller.state.document.layers.single as TextCanvasLayer;
      expect(t.highlightColor, const Color(0xFFFFFF00));
      expect(t.strokeColor, const Color(0xFF000000));
      expect(t.strokeWidth, 2);

      controller.updateSelectedTextDecoration(clearHighlight: true);
      controller.updateSelectedTextDecoration(clearStroke: true, strokeWidth: 0);
      t = controller.state.document.layers.single as TextCanvasLayer;
      expect(t.highlightColor, isNull);
      expect(t.strokeColor, isNull);
    });

    test('shape style edits set border and corner radius; clearStroke removes it', () {
      final controller = CanvasController(document);
      controller.selectLayerById('layer_a');
      controller.updateSelectedShapeStyle(
        strokeColor: const Color(0xFFFF0000),
        strokeWidth: 4,
        cornerRadius: 12,
      );
      var a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a')
          as ShapeCanvasLayer;
      expect(a.strokeColor, const Color(0xFFFF0000));
      expect(a.strokeWidth, 4);
      expect(a.cornerRadius, 12);

      controller.updateSelectedShapeStyle(clearStroke: true);
      a = controller.state.document.layers.firstWhere((l) => l.id == 'layer_a')
          as ShapeCanvasLayer;
      expect(a.strokeColor, isNull);
    });
  });
}
