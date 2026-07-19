import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/canvas_document.dart';
import '../models/canvas_layer.dart';
import 'canvas_image_cache.dart';

/// Paints the artboard and every layer on it, in one pass, in a single
/// coordinate space transform per layer (translate to center, rotate,
/// translate to top-left) — this is what lets shapes/text/images share
/// identical rotation/opacity handling rather than each needing its own
/// special-cased logic.
///
/// `scale` and `offset` convert from artboard space to widget space —
/// owned and computed by CanvasSurface (letterboxing the artboard to fit
/// available space while preserving aspect ratio), not by this painter.
class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.document,
    required this.selectedLayerId,
    required this.scale,
    required this.offset,
    required this.imageCache,
  }) : super(repaint: imageCache);

  final CanvasDocument document;
  final String? selectedLayerId;
  final double scale;
  final Offset offset;
  final CanvasImageCache imageCache;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // Artboard background — makes the artboard's extent visible even
    // before any layers are added, and gives images/shapes with
    // transparency something defined to render over.
    final artboardRect = Rect.fromLTWH(0, 0, document.width * scale, document.height * scale);
    canvas.drawRect(artboardRect, Paint()..color = Colors.white);

    for (final layer in document.layers) {
      _paintLayer(canvas, layer);

      if (layer.id == selectedLayerId) {
        _paintSelectionOutline(canvas, layer);
      }
    }

    canvas.restore();
  }

  void _paintLayer(Canvas canvas, CanvasLayer layer) {
    canvas.save();

    final centerX = (layer.x + layer.width / 2) * scale;
    final centerY = (layer.y + layer.height / 2) * scale;
    canvas.translate(centerX, centerY);
    canvas.rotate(layer.rotationDegrees * math.pi / 180);
    canvas.translate(-layer.width * scale / 2, -layer.height * scale / 2);

    final bounds = Rect.fromLTWH(0, 0, layer.width * scale, layer.height * scale);
    final needsOpacityLayer = layer.opacity < 1.0;
    if (needsOpacityLayer) {
      canvas.saveLayer(bounds, Paint()..color = Colors.black.withOpacity(layer.opacity));
    }

    switch (layer) {
      case ImageCanvasLayer(:final imageUrl):
        imageCache.ensureLoaded(imageUrl);
        final image = imageCache.get(imageUrl);
        if (image != null) {
          paintImage(canvas: canvas, rect: bounds, image: image, fit: BoxFit.cover);
        } else {
          // Not loaded yet (or failed) — a neutral placeholder rather
          // than leaving a hole; ensureLoaded above will trigger a
          // repaint (via imageCache's own notifyListeners) once ready.
          canvas.drawRect(bounds, Paint()..color = Colors.grey.shade300);
        }

      case TextCanvasLayer(:final text, :final fontSize, :final color, :final fontFamily):
        final textPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(fontSize: fontSize * scale, color: color, fontFamily: fontFamily),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bounds.width);
        textPainter.paint(canvas, Offset.zero);

      case ShapeCanvasLayer(:final shapeKind, :final fillColor):
        final paint = Paint()..color = fillColor;
        if (shapeKind == ShapeKind.ellipse) {
          canvas.drawOval(bounds, paint);
        } else {
          canvas.drawRect(bounds, paint);
        }
    }

    if (needsOpacityLayer) {
      canvas.restore(); // matches saveLayer
    }

    canvas.restore(); // matches the translate/rotate save
  }

  void _paintSelectionOutline(Canvas canvas, CanvasLayer layer) {
    canvas.save();

    final centerX = (layer.x + layer.width / 2) * scale;
    final centerY = (layer.y + layer.height / 2) * scale;
    canvas.translate(centerX, centerY);
    canvas.rotate(layer.rotationDegrees * math.pi / 180);
    canvas.translate(-layer.width * scale / 2, -layer.height * scale / 2);

    final outlinePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(-1, -1, layer.width * scale + 2, layer.height * scale + 2),
      outlinePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.selectedLayerId != selectedLayerId ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset;
  }
}
