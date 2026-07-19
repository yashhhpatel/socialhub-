import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/canvas/hit_testing.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';

void main() {
  group('layerContainsPoint (unrotated)', () {
    final layer = ShapeCanvasLayer(
      id: 'layer_1',
      x: 100,
      y: 100,
      width: 200,
      height: 100,
      shapeKind: ShapeKind.rectangle,
    );

    test('point inside bounds hits', () {
      expect(layerContainsPoint(layer, const Offset(150, 150)), isTrue);
    });

    test('point exactly on an edge hits (inclusive bounds)', () {
      expect(layerContainsPoint(layer, const Offset(100, 100)), isTrue);
      expect(layerContainsPoint(layer, const Offset(300, 200)), isTrue);
    });

    test('point outside bounds misses', () {
      expect(layerContainsPoint(layer, const Offset(50, 50)), isFalse);
      expect(layerContainsPoint(layer, const Offset(350, 150)), isFalse);
    });
  });

  group('layerContainsPoint (rotated)', () {
    // A layer centered at (100, 100), 40x40, rotated 90 degrees. Since
    // it's square and centered, rotation doesn't change its footprint —
    // this isolates whether the rotation math is being applied at all
    // without needing to reason about a rotated rectangle's new bounds.
    final squareLayer = ShapeCanvasLayer(
      id: 'square',
      x: 80,
      y: 80,
      width: 40,
      height: 40,
      rotationDegrees: 90,
      shapeKind: ShapeKind.rectangle,
    );

    test('center point still hits after rotation', () {
      expect(layerContainsPoint(squareLayer, const Offset(100, 100)), isTrue);
    });

    // A tall, narrow layer (20 wide, 100 tall) centered at (100, 100),
    // rotated 90 degrees so it now visually occupies a WIDE, SHORT
    // footprint on screen. A point that would only be inside the
    // ORIGINAL (unrotated) bounds, but is outside the visually-rotated
    // footprint, must miss — and vice versa. This is what actually
    // proves the rotation transform is correct, not just present.
    final tallLayer = ShapeCanvasLayer(
      id: 'tall',
      x: 90, // center x = 90 + 10 = 100
      y: 50, // center y = 50 + 50 = 100
      width: 20,
      height: 100,
      rotationDegrees: 90,
      shapeKind: ShapeKind.rectangle,
    );

    test('point within the ROTATED (visual) footprint hits', () {
      // After a 90-degree rotation, the tall layer's visual footprint
      // is now wide (100) and short (20), still centered at (100,100):
      // roughly x in [50,150], y in [90,110].
      expect(layerContainsPoint(tallLayer, const Offset(140, 100)), isTrue);
    });

    test('point within the layer\'s UNROTATED bounds, but outside the rotated footprint, misses', () {
      // (95, 40) is within the original unrotated rect (x:90-110, y:50-150)
      // but well outside the rotated (visual) footprint (y range ~90-110).
      expect(layerContainsPoint(tallLayer, const Offset(95, 40)), isFalse);
    });
  });

  group('hitTestLayers', () {
    test('returns null when no layer contains the point', () {
      final layers = [
        ShapeCanvasLayer(id: 'a', x: 0, y: 0, width: 10, height: 10, shapeKind: ShapeKind.rectangle),
      ];
      expect(hitTestLayers(layers, const Offset(500, 500)), isNull);
    });

    test('returns the TOPMOST (last in list) layer when overlapping layers both contain the point', () {
      final bottom = ShapeCanvasLayer(
        id: 'bottom',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        shapeKind: ShapeKind.rectangle,
      );
      final top = ShapeCanvasLayer(
        id: 'top',
        x: 20,
        y: 20,
        width: 50,
        height: 50,
        shapeKind: ShapeKind.rectangle,
      );

      final result = hitTestLayers([bottom, top], const Offset(40, 40));
      expect(result?.id, 'top');
    });

    test('falls through to a lower layer if the point misses the topmost one', () {
      final bottom = ShapeCanvasLayer(
        id: 'bottom',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        shapeKind: ShapeKind.rectangle,
      );
      final top = ShapeCanvasLayer(
        id: 'top',
        x: 20,
        y: 20,
        width: 30,
        height: 30,
        shapeKind: ShapeKind.rectangle,
      );

      // (80, 80) is within `bottom` but outside `top`.
      final result = hitTestLayers([bottom, top], const Offset(80, 80));
      expect(result?.id, 'bottom');
    });
  });
}
