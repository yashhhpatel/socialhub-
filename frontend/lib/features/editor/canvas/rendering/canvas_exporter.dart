import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/canvas_document.dart';
import '../models/canvas_layer.dart';
import 'canvas_image_cache.dart';
import 'canvas_painter.dart';

/// Rasterizes a CanvasDocument to a PNG at its exact artboard size
/// (Milestone 3.6).
///
/// This is the "create once" half of the publish pipeline: the resulting
/// master render is uploaded to Cloudinary, and Milestone 4.1's variant
/// generation crops/resizes THAT into each platform's spec. Rendering
/// here — in the same CanvasPainter the editor draws with — is what
/// guarantees the published image matches what the user designed. A
/// server-side renderer would be a second implementation free to drift.
///
/// Deliberately NOT a RepaintBoundary screenshot. The on-screen canvas is
/// letterboxed and scaled to whatever space the panels leave it, so
/// capturing the widget would bake in that scale plus the surrounding
/// dead space, and would also include the selection outline. Driving the
/// painter directly against a PictureRecorder gives exactly
/// document.width x document.height, with no selection chrome, regardless
/// of window size.
class CanvasExporter {
  const CanvasExporter._();

  /// Renders [document] and returns PNG bytes.
  ///
  /// Uses its own image cache rather than borrowing the editor's: that
  /// one is owned by CanvasSurface's State, and threading it out through
  /// the widget tree purely for export would couple the export path to
  /// the on-screen widget's lifecycle. Any image layer is loaded and
  /// awaited here — otherwise the export would race the network and
  /// silently produce a design with missing pictures.
  static Future<Uint8List> toPng(CanvasDocument document) async {
    final imageCache = CanvasImageCache();
    try {
      return await _render(document, imageCache);
    } finally {
      imageCache.dispose();
    }
  }

  static Future<Uint8List> _render(
    CanvasDocument document,
    CanvasImageCache imageCache,
  ) async {
    await _awaitPendingImages(document, imageCache);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    CanvasPainter(
      document: document,
      // No selection outline in an exported design — that's editor
      // chrome, not part of the artwork.
      selectedLayerId: null,
      scale: 1,
      offset: Offset.zero,
      imageCache: imageCache,
    ).paint(canvas, Size(document.width, document.height));

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        document.width.round(),
        document.height.round(),
      );
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          throw StateError('Canvas export produced no image data.');
        }
        return bytes.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// Waits for every image layer's bitmap to be decoded and in the cache.
  ///
  /// Polls rather than awaiting a future because CanvasImageCache is a
  /// fire-and-forget ChangeNotifier built for painting (where a late
  /// image simply triggers a repaint) and exposes no per-URL completion
  /// signal. Bounded so a permanently-broken image URL degrades to
  /// "exported without that layer" instead of hanging the export forever.
  static Future<void> _awaitPendingImages(
    CanvasDocument document,
    CanvasImageCache imageCache,
  ) async {
    final urls = <String>{
      for (final layer in document.layers)
        if (layer is ImageCanvasLayer) layer.imageUrl,
    };
    if (urls.isEmpty) return;

    for (final url in urls) {
      imageCache.ensureLoaded(url);
    }

    const attemptDelay = Duration(milliseconds: 100);
    const maxAttempts = 50; // 5s ceiling
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (urls.every((url) => imageCache.get(url) != null)) return;
      await Future<void>.delayed(attemptDelay);
    }
  }
}
