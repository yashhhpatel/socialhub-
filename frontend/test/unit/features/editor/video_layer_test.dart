import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';

void main() {
  group('VideoCanvasLayer serialization', () {
    test('round-trips through toJson / CanvasLayer.fromJson', () {
      const layer = VideoCanvasLayer(
        id: 'v1',
        x: 10,
        y: 20,
        width: 320,
        height: 180,
        videoUrl: 'https://cdn.test/clip.mp4',
        posterUrl: 'https://cdn.test/poster.png',
        trimStartSeconds: 2.5,
        trimEndSeconds: 9,
      );

      final restored = CanvasLayer.fromJson(layer.toJson());
      expect(restored, isA<VideoCanvasLayer>());
      final v = restored as VideoCanvasLayer;
      expect(v.videoUrl, 'https://cdn.test/clip.mp4');
      expect(v.posterUrl, 'https://cdn.test/poster.png');
      expect(v.trimStartSeconds, 2.5);
      expect(v.trimEndSeconds, 9);
      expect(v.width, 320);
    });

    test('preserves a null (open) trim end and null poster across a round-trip', () {
      const layer = VideoCanvasLayer(
        id: 'v1',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        videoUrl: 'https://cdn.test/clip.mp4',
      );

      final v = CanvasLayer.fromJson(layer.toJson()) as VideoCanvasLayer;
      expect(v.trimStartSeconds, 0);
      expect(v.trimEndSeconds, isNull);
      expect(v.posterUrl, isNull);
    });
  });

  group('VideoCanvasLayer.copyWithTrim', () {
    const base = VideoCanvasLayer(
      id: 'v1',
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      videoUrl: 'https://cdn.test/clip.mp4',
      trimStartSeconds: 1,
      trimEndSeconds: 8,
    );

    test('updates only the bound provided', () {
      expect(base.copyWithTrim(trimStartSeconds: 3).trimStartSeconds, 3);
      expect(base.copyWithTrim(trimStartSeconds: 3).trimEndSeconds, 8);
      expect(base.copyWithTrim(trimEndSeconds: 5).trimEndSeconds, 5);
    });

    test('clearEnd resets the end to open regardless of a passed value', () {
      final cleared = base.copyWithTrim(clearEnd: true);
      expect(cleared.trimEndSeconds, isNull);
      expect(cleared.trimStartSeconds, 1); // untouched
    });
  });

  group('VideoCanvasLayer.copyWithGeometry', () {
    test('keeps video-specific fields when geometry changes', () {
      const base = VideoCanvasLayer(
        id: 'v1',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        videoUrl: 'https://cdn.test/clip.mp4',
        posterUrl: 'https://cdn.test/p.png',
        trimStartSeconds: 2,
      );

      final moved = base.copyWithGeometry(x: 50, width: 200);
      expect(moved.x, 50);
      expect(moved.width, 200);
      expect(moved.videoUrl, 'https://cdn.test/clip.mp4');
      expect(moved.posterUrl, 'https://cdn.test/p.png');
      expect(moved.trimStartSeconds, 2);
    });
  });
}
