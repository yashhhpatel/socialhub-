import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';

void main() {
  group('ImageCanvasLayer.copyWithGeometry', () {
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

      final moved = layer.copyWithGeometry(x: 99, y: 88);

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

  group('TextCanvasLayer.copyWithGeometry', () {
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

      final moved = layer.copyWithGeometry(x: 5, y: 5);

      expect(moved.x, 5);
      expect(moved.y, 5);
      expect(moved.text, layer.text);
      expect(moved.fontSize, layer.fontSize);
      expect(moved.color, layer.color);
      expect(moved.fontFamily, layer.fontFamily);
    });
  });

  group('ShapeCanvasLayer.copyWithGeometry', () {
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

      final moved = layer.copyWithGeometry(x: -10, y: -20);

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

  group('copyWithGeometry partial updates', () {
    test('passing only width leaves x/y/height/rotation/opacity untouched', () {
      const layer = ShapeCanvasLayer(
        id: 's',
        x: 10,
        y: 20,
        width: 100,
        height: 100,
        rotationDegrees: 30,
        opacity: 0.5,
        shapeKind: ShapeKind.rectangle,
      );

      final resized = layer.copyWithGeometry(width: 250);

      expect(resized.width, 250);
      expect(resized.x, layer.x);
      expect(resized.y, layer.y);
      expect(resized.height, layer.height);
      expect(resized.rotationDegrees, layer.rotationDegrees);
      expect(resized.opacity, layer.opacity);
    });

    test('passing only rotationDegrees leaves everything else untouched', () {
      const layer = ShapeCanvasLayer(
        id: 's',
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        shapeKind: ShapeKind.rectangle,
      );

      final rotated = layer.copyWithGeometry(rotationDegrees: 90);

      expect(rotated.rotationDegrees, 90);
      expect(rotated.x, 10);
      expect(rotated.width, 100);
    });

    test('passing nothing at all returns an equivalent (all fields unchanged) layer', () {
      const layer = ShapeCanvasLayer(
        id: 's',
        x: 1,
        y: 2,
        width: 3,
        height: 4,
        rotationDegrees: 5,
        opacity: 0.6,
        shapeKind: ShapeKind.ellipse,
      );

      final unchanged = layer.copyWithGeometry();

      expect(unchanged.x, layer.x);
      expect(unchanged.y, layer.y);
      expect(unchanged.width, layer.width);
      expect(unchanged.height, layer.height);
      expect(unchanged.rotationDegrees, layer.rotationDegrees);
      expect(unchanged.opacity, layer.opacity);
    });
  });

  group('subtype-specific copyWith* methods', () {
    test('ShapeCanvasLayer.copyWithFillColor updates only the fill color', () {
      const layer = ShapeCanvasLayer(
        id: 's',
        x: 0,
        y: 0,
        width: 10,
        height: 10,
        shapeKind: ShapeKind.rectangle,
        fillColor: Color(0xFF000000),
      );

      final recolored = layer.copyWithFillColor(const Color(0xFFFFFFFF));

      expect(recolored.fillColor, const Color(0xFFFFFFFF));
      expect(recolored.x, layer.x);
      expect(recolored.shapeKind, layer.shapeKind);
    });

    test('TextCanvasLayer.copyWithColor updates only the text color', () {
      const layer = TextCanvasLayer(
        id: 't',
        x: 0,
        y: 0,
        width: 10,
        height: 10,
        text: 'Hi',
      );

      final recolored = layer.copyWithColor(const Color(0xFF00FF00));

      expect(recolored.color, const Color(0xFF00FF00));
      expect(recolored.text, layer.text);
    });

    test('TextCanvasLayer.copyWithText updates only the text content', () {
      const layer = TextCanvasLayer(id: 't', x: 0, y: 0, width: 10, height: 10, text: 'Hi');
      final edited = layer.copyWithText('Goodbye');

      expect(edited.text, 'Goodbye');
      expect(edited.color, layer.color);
    });

    test('ImageCanvasLayer.copyWithImageUrl updates only the image URL', () {
      const layer = ImageCanvasLayer(
        id: 'i',
        x: 0,
        y: 0,
        width: 10,
        height: 10,
        imageUrl: 'https://example.com/a.jpg',
      );

      final swapped = layer.copyWithImageUrl('https://example.com/b.jpg');

      expect(swapped.imageUrl, 'https://example.com/b.jpg');
      expect(swapped.x, layer.x);
    });
  });
}
