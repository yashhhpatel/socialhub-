import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:socialhub/features/editor/canvas/brand_kit_application.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_document.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';

CanvasDocument _doc(List<CanvasLayer> layers) =>
    CanvasDocument(width: 1080, height: 1080, layers: layers);

TextCanvasLayer _text() => const TextCanvasLayer(
      id: 't1',
      x: 0,
      y: 0,
      width: 200,
      height: 40,
      text: 'Hello',
      color: Color(0xFF000000),
    );

ShapeCanvasLayer _shape() => const ShapeCanvasLayer(
      id: 's1',
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      shapeKind: ShapeKind.rectangle,
      fillColor: Color(0xFF000000),
    );

ImageCanvasLayer _image() => const ImageCanvasLayer(
      id: 'i1',
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      imageUrl: 'https://cdn.test/a.png',
    );

void main() {
  group('applyBrandKit', () {
    test('applies the primary colour + font to text and the accent to shapes', () {
      const kit = BrandKit(
        id: 'bk',
        colors: ['#FF0000', '#00FF00'],
        fonts: ['Inter'],
      );

      final result = applyBrandKit(_doc([_text(), _shape(), _image()]), kit);

      final text = result.layers[0] as TextCanvasLayer;
      final shape = result.layers[1] as ShapeCanvasLayer;
      final image = result.layers[2] as ImageCanvasLayer;

      expect(text.color, const Color(0xFFFF0000)); // primary
      expect(text.fontFamily, 'Inter');
      expect(shape.fillColor, const Color(0xFF00FF00)); // accent (2nd colour)
      expect(image.imageUrl, 'https://cdn.test/a.png'); // untouched
    });

    test('shapes use the primary when only one colour is defined', () {
      const kit = BrandKit(id: 'bk', colors: ['#123456']);
      final result = applyBrandKit(_doc([_shape()]), kit);
      expect((result.layers[0] as ShapeCanvasLayer).fillColor, const Color(0xFF123456));
    });

    test('leaves a field untouched when the kit does not define it', () {
      // Fonts only: colours must be left as they were.
      const kit = BrandKit(id: 'bk', fonts: ['Roboto']);
      final result = applyBrandKit(_doc([_text()]), kit);
      final text = result.layers[0] as TextCanvasLayer;
      expect(text.fontFamily, 'Roboto');
      expect(text.color, const Color(0xFF000000)); // unchanged
    });

    test('an empty kit is a no-op that returns the same document', () {
      final doc = _doc([_text(), _shape()]);
      expect(applyBrandKit(doc, const BrandKit(id: 'bk')), same(doc));
    });

    test('parses shorthand and alpha hex forms', () {
      const kit = BrandKit(id: 'bk', colors: ['#f00']); // shorthand red
      final result = applyBrandKit(_doc([_text()]), kit);
      expect((result.layers[0] as TextCanvasLayer).color, const Color(0xFFFF0000));
    });

    test('skips recolouring on a malformed hex rather than throwing', () {
      const kit = BrandKit(id: 'bk', colors: ['not-a-colour']);
      final result = applyBrandKit(_doc([_text()]), kit);
      // Colour left as-is; no exception.
      expect((result.layers[0] as TextCanvasLayer).color, const Color(0xFF000000));
    });
  });
}
