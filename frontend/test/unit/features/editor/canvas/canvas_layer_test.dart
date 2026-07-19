import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';

void main() {
  group('ImageCanvasLayer.copyWithPosition', () {
    test('updates only x/y, preserving every other field exactly', () {
      const layer = ImageCanvasLayer(
        id: 'img_1',
        x: 10,
        y: 20,
        width: 200,
        height: 150,
        rotationDegrees: 45,
        opacity: 0.8,
        imageUrl: 'https://example.com/photo.jpg',
      );

      final moved = layer.copyWithPosition(99, 88);

      expect(moved.x, 99);
      expect(moved.y, 88);
      expect(moved.id, layer.id);
      expect(moved.width, layer.width);
      expect(moved.height, layer.height);
      expect(moved.rotationDegrees, layer.rotationDegrees);
      expect(moved.opacity, layer.opacity);
      expect(moved.imageUrl, layer.imageUrl);
    });
  });

  group('TextCanvasLayer.copyWithPosition', () {
    test('updates only x/y, preserving every other field exactly', () {
      const layer = TextCanvasLayer(
        id: 'text_1',
        x: 10,
        y: 20,
        width: 200,
        height: 50,
        text: 'Hello world',
        fontSize: 32,
        color: Color(0xFFFF0000),
        fontFamily: 'Inter',
      );

      final moved = layer.copyWithPosition(5, 5);

      expect(moved.x, 5);
      expect(moved.y, 5);
      expect(moved.text, layer.text);
      expect(moved.fontSize, layer.fontSize);
      expect(moved.color, layer.color);
      expect(moved.fontFamily, layer.fontFamily);
    });
  });

  group('ShapeCanvasLayer.copyWithPosition', () {
    test('updates only x/y, preserving every other field exactly', () {
      const layer = ShapeCanvasLayer(
        id: 'shape_1',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        shapeKind: ShapeKind.ellipse,
        fillColor: Color(0xFF00FF00),
      );

      final moved = layer.copyWithPosition(-10, -20);

      expect(moved.x, -10);
      expect(moved.y, -20);
      expect(moved.shapeKind, layer.shapeKind);
      expect(moved.fillColor, layer.fillColor);
    });
  });

  group('CanvasLayer.center', () {
    test('computes the midpoint of x/y/width/height', () {
      const layer = ShapeCanvasLayer(
        id: 's',
        x: 100,
        y: 50,
        width: 40,
        height: 20,
        shapeKind: ShapeKind.rectangle,
      );

      expect(layer.center, const Offset(120, 60));
    });
  });
}
