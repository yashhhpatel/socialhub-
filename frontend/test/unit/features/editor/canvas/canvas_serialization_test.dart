import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_document.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';

/// Round-trip coverage for the autosave wire format (Milestone 3.5).
/// These are the tests that catch the worst class of bug in this feature:
/// a field that saves but doesn't load, which shows up to the user as
/// silently losing part of a design on reload.
void main() {
  group('CanvasDocument serialization', () {
    test('round-trips an empty artboard', () {
      const document = CanvasDocument(width: 1080, height: 1350);
      final restored = CanvasDocument.fromJson(document.toJson());

      expect(restored.width, 1080);
      expect(restored.height, 1350);
      expect(restored.layers, isEmpty);
    });

    test('round-trips every layer type with all fields intact', () {
      const document = CanvasDocument(
        width: 1080,
        height: 1080,
        layers: [
          ShapeCanvasLayer(
            id: 'shape_1',
            x: 10,
            y: 20,
            width: 200,
            height: 120,
            rotationDegrees: 45,
            opacity: 0.5,
            shapeKind: ShapeKind.ellipse,
            fillColor: Color(0xFF112233),
          ),
          TextCanvasLayer(
            id: 'text_1',
            x: 30,
            y: 40,
            width: 300,
            height: 60,
            rotationDegrees: 15,
            opacity: 0.8,
            text: 'Hello SocialHub',
            fontSize: 32,
            color: Color(0xFFAABBCC),
            fontFamily: 'Inter',
          ),
          ImageCanvasLayer(
            id: 'image_1',
            x: 50,
            y: 60,
            width: 400,
            height: 400,
            imageUrl: 'https://example.com/a.jpg',
          ),
        ],
      );

      final restored = CanvasDocument.fromJson(document.toJson());
      expect(restored.layers.length, 3);

      final shape = restored.layers[0] as ShapeCanvasLayer;
      expect(shape.id, 'shape_1');
      expect(shape.x, 10);
      expect(shape.y, 20);
      expect(shape.width, 200);
      expect(shape.height, 120);
      expect(shape.rotationDegrees, 45);
      expect(shape.opacity, 0.5);
      expect(shape.shapeKind, ShapeKind.ellipse);
      expect(shape.fillColor, const Color(0xFF112233));

      final text = restored.layers[1] as TextCanvasLayer;
      expect(text.text, 'Hello SocialHub');
      expect(text.fontSize, 32);
      expect(text.color, const Color(0xFFAABBCC));
      expect(text.fontFamily, 'Inter');
      expect(text.rotationDegrees, 15);
      expect(text.opacity, 0.8);

      final image = restored.layers[2] as ImageCanvasLayer;
      expect(image.imageUrl, 'https://example.com/a.jpg');
      expect(image.width, 400);
    });

    test('preserves layer ORDER, which is z-order on the canvas', () {
      const document = CanvasDocument(
        width: 100,
        height: 100,
        layers: [
          ShapeCanvasLayer(id: 'bottom', x: 0, y: 0, width: 1, height: 1, shapeKind: ShapeKind.rectangle),
          ShapeCanvasLayer(id: 'middle', x: 0, y: 0, width: 1, height: 1, shapeKind: ShapeKind.rectangle),
          ShapeCanvasLayer(id: 'top', x: 0, y: 0, width: 1, height: 1, shapeKind: ShapeKind.rectangle),
        ],
      );

      final restored = CanvasDocument.fromJson(document.toJson());
      expect(restored.layers.map((l) => l.id).toList(), ['bottom', 'middle', 'top']);
    });

    test('survives a real JSON encode/decode cycle, not just a Map copy', () {
      // The map handed to Dio is encoded to a JSON string on the wire and
      // decoded on the way back — which turns whole doubles into ints.
      // This is the case a Map-only round trip would miss entirely.
      const document = CanvasDocument(
        width: 1080,
        height: 1080,
        layers: [
          ShapeCanvasLayer(
            id: 'whole_numbers',
            x: 100, // encodes as int 100, not 100.0
            y: 200,
            width: 300,
            height: 400,
            shapeKind: ShapeKind.rectangle,
          ),
        ],
      );

      final decoded = jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
      final restored = CanvasDocument.fromJson(decoded);

      final layer = restored.layers.single;
      expect(layer.x, 100);
      expect(layer.y, 200);
      expect(layer.width, 300);
      expect(layer.height, 400);
      expect(restored.width, 1080);
    });

    test('throws a clear FormatException on an unknown layer type', () {
      expect(
        () => CanvasLayer.fromJson({'type': 'hologram', 'id': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('document JSON matches the backend CanvasJsonDto contract keys', () {
      const document = CanvasDocument(width: 1, height: 1);
      expect(document.toJson().keys.toSet(), {'width', 'height', 'layers'});
    });
  });
}
