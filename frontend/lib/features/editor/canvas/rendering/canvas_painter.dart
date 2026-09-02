import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/canvas_document.dart';
import '../models/canvas_layer.dart';
import '../state/canvas_controller.dart' show ResizeHandle;
import 'canvas_image_cache.dart';

/// Visual size (screen px) of a resize handle square.
const double kHandleSize = 10;

/// Gap (screen px) between the top edge and the rotate knob.
const double kRotateHandleGap = 26;

/// Screen-space centres of the eight resize handles for a layer's
/// axis-aligned box, at [scale]. Shared by the painter (to draw them) and the
/// surface (to hit-test them) so the two never drift apart.
Map<ResizeHandle, Offset> resizeHandleCenters(CanvasLayer layer, double scale) {
  final bx = layer.x * scale;
  final by = layer.y * scale;
  final bw = layer.width * scale;
  final bh = layer.height * scale;
  return {
    ResizeHandle.nw: Offset(bx, by),
    ResizeHandle.n: Offset(bx + bw / 2, by),
    ResizeHandle.ne: Offset(bx + bw, by),
    ResizeHandle.e: Offset(bx + bw, by + bh / 2),
    ResizeHandle.se: Offset(bx + bw, by + bh),
    ResizeHandle.s: Offset(bx + bw / 2, by + bh),
    ResizeHandle.sw: Offset(bx, by + bh),
    ResizeHandle.w: Offset(bx, by + bh / 2),
  };
}

/// Screen-space centre of the rotate knob (above the top edge).
Offset rotateHandleCenter(CanvasLayer layer, double scale) => Offset(
      (layer.x + layer.width / 2) * scale,
      layer.y * scale - kRotateHandleGap,
    );

/// A snap guide line to draw over the artboard while dragging — a vertical or
/// horizontal line at an artboard-space [position].
enum GuideAxis { vertical, horizontal }

class CanvasGuide {
  const CanvasGuide(this.axis, this.position);
  final GuideAxis axis;
  final double position;

  @override
  bool operator ==(Object other) =>
      other is CanvasGuide && other.axis == axis && other.position == position;

  @override
  int get hashCode => Object.hash(axis, position);
}

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
    required this.selectedLayerIds,
    required this.scale,
    required this.offset,
    required this.imageCache,
    this.guides = const [],
    this.marquee,
  }) : super(repaint: imageCache);

  final CanvasDocument document;
  final Set<String> selectedLayerIds;
  final double scale;
  final Offset offset;
  final CanvasImageCache imageCache;
  final List<CanvasGuide> guides;

  /// The in-progress marquee-selection rectangle, in artboard space, or null.
  final Rect? marquee;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // Artboard background — the document's own background colour (defaults to
    // white). Makes the artboard's extent visible even before any layers are
    // added, and gives transparent layers something defined to render over.
    final artboardRect = Rect.fromLTWH(0, 0, document.width * scale, document.height * scale);
    canvas.drawRect(artboardRect, Paint()..color = document.backgroundColor);

    for (final layer in document.layers) {
      if (layer.hidden) continue; // hidden layers stay in the doc but don't paint

      _paintLayer(canvas, layer);

      if (selectedLayerIds.contains(layer.id)) {
        _paintSelectionOutline(canvas, layer);
        // Resize/rotate handles only make sense for a single selection.
        if (selectedLayerIds.length == 1) _paintHandles(canvas, layer);
      }
    }

    _paintGuides(canvas);
    _paintMarquee(canvas);

    canvas.restore();
  }

  /// Draws the marquee-selection rectangle (a translucent accent fill + border).
  void _paintMarquee(Canvas canvas) {
    final m = marquee;
    if (m == null) return;
    final rect = Rect.fromLTRB(
      m.left * scale,
      m.top * scale,
      m.right * scale,
      m.bottom * scale,
    );
    canvas.drawRect(rect, Paint()..color = Colors.blueAccent.withOpacity(0.12));
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Draws the rotate knob (always) and the eight resize handles (only when
  /// the layer is unrotated — resizing a rotated layer is done from the
  /// property panel). Coordinates match [resizeHandleCenters] exactly so the
  /// surface's hit-testing lines up with what's drawn.
  void _paintHandles(Canvas canvas, CanvasLayer layer) {
    final fill = Paint()..color = Colors.white;
    final border = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Rotate knob + its connector line to the top edge.
    final knob = rotateHandleCenter(layer, scale);
    final topEdge = Offset((layer.x + layer.width / 2) * scale, layer.y * scale);
    canvas.drawLine(topEdge, knob, border);
    canvas.drawCircle(knob, kHandleSize / 2, fill);
    canvas.drawCircle(knob, kHandleSize / 2, border);

    if (layer.rotationDegrees != 0) return; // resize handles: unrotated only

    for (final center in resizeHandleCenters(layer, scale).values) {
      final rect = Rect.fromCenter(
        center: center,
        width: kHandleSize,
        height: kHandleSize,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
    }
  }

  void _paintLayer(Canvas canvas, CanvasLayer layer) {
    canvas.save();

    final centerX = (layer.x + layer.width / 2) * scale;
    final centerY = (layer.y + layer.height / 2) * scale;
    canvas.translate(centerX, centerY);
    canvas.rotate(layer.rotationDegrees * math.pi / 180);
    if (layer.flipH || layer.flipV) {
      canvas.scale(layer.flipH ? -1.0 : 1.0, layer.flipV ? -1.0 : 1.0);
    }
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

      case TextCanvasLayer(
          :final text,
          :final fontSize,
          :final color,
          :final fontFamily,
          :final bold,
          :final italic,
          :final align,
          :final lineHeight,
        ):
        final textPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: fontSize * scale,
              color: color,
              fontFamily: fontFamily,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              height: lineHeight,
            ),
          ),
          textAlign: align,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bounds.width);
        textPainter.paint(canvas, Offset.zero);

      case ShapeCanvasLayer(
          :final shapeKind,
          :final fillColor,
          :final strokeColor,
          :final strokeWidth,
          :final cornerRadius,
        ):
        final fill = Paint()..color = fillColor;
        final stroke = (strokeColor != null && strokeWidth > 0)
            ? _strokePaint(strokeColor, strokeWidth)
            : null;
        switch (shapeKind) {
          case ShapeKind.ellipse:
            canvas.drawOval(bounds, fill);
            if (stroke != null) canvas.drawOval(bounds, stroke);
          case ShapeKind.rectangle:
            if (cornerRadius > 0) {
              final rrect = RRect.fromRectAndRadius(
                bounds,
                Radius.circular(cornerRadius * scale),
              );
              canvas.drawRRect(rrect, fill);
              if (stroke != null) canvas.drawRRect(rrect, stroke);
            } else {
              canvas.drawRect(bounds, fill);
              if (stroke != null) canvas.drawRect(bounds, stroke);
            }
          case ShapeKind.triangle:
          case ShapeKind.star:
          case ShapeKind.diamond:
            final path = _polygonPath(shapeKind, bounds);
            canvas.drawPath(path, fill);
            if (stroke != null) canvas.drawPath(path, stroke);
        }

      case VideoCanvasLayer(:final posterUrl):
        // A CustomPainter can't play video (see VideoCanvasLayer), so paint
        // the poster still if there is one, then a play badge so it reads
        // as a video rather than a plain image.
        if (posterUrl != null) {
          imageCache.ensureLoaded(posterUrl);
          final poster = imageCache.get(posterUrl);
          if (poster != null) {
            paintImage(canvas: canvas, rect: bounds, image: poster, fit: BoxFit.cover);
          } else {
            canvas.drawRect(bounds, Paint()..color = Colors.black87);
          }
        } else {
          canvas.drawRect(bounds, Paint()..color = Colors.black87);
        }
        _paintPlayBadge(canvas, bounds);
    }

    if (needsOpacityLayer) {
      canvas.restore(); // matches saveLayer
    }

    canvas.restore(); // matches the translate/rotate save
  }

  Paint _strokePaint(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * scale;

  /// Builds the outline for a polygon shape (triangle / diamond / 5-point
  /// star) inscribed in [bounds]. Rect/ellipse use their own draw calls.
  Path _polygonPath(ShapeKind kind, Rect bounds) {
    final path = Path();
    switch (kind) {
      case ShapeKind.triangle:
        path
          ..moveTo(bounds.center.dx, bounds.top)
          ..lineTo(bounds.right, bounds.bottom)
          ..lineTo(bounds.left, bounds.bottom)
          ..close();
      case ShapeKind.diamond:
        path
          ..moveTo(bounds.center.dx, bounds.top)
          ..lineTo(bounds.right, bounds.center.dy)
          ..lineTo(bounds.center.dx, bounds.bottom)
          ..lineTo(bounds.left, bounds.center.dy)
          ..close();
      case ShapeKind.star:
        const points = 5;
        final cx = bounds.center.dx;
        final cy = bounds.center.dy;
        final outer = math.min(bounds.width, bounds.height) / 2;
        final inner = outer * 0.42;
        for (var i = 0; i < points * 2; i++) {
          final r = i.isEven ? outer : inner;
          // Start at the top point (-90°) and step around.
          final angle = -math.pi / 2 + i * math.pi / points;
          final x = cx + r * math.cos(angle);
          final y = cy + r * math.sin(angle);
          i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        path.close();
      case ShapeKind.rectangle:
      case ShapeKind.ellipse:
        path.addRect(bounds); // not used (handled above), kept exhaustive
    }
    return path;
  }

  /// Centered translucent circle + play triangle, sized to the layer, so a
  /// video layer is visually distinct from an image one on the canvas.
  void _paintPlayBadge(Canvas canvas, Rect bounds) {
    final center = bounds.center;
    final radius = math.min(bounds.width, bounds.height) * 0.18;
    if (radius <= 0) return;

    canvas.drawCircle(center, radius, Paint()..color = Colors.black.withOpacity(0.55));

    final t = radius * 0.5;
    final triangle = Path()
      ..moveTo(center.dx - t * 0.6, center.dy - t)
      ..lineTo(center.dx - t * 0.6, center.dy + t)
      ..lineTo(center.dx + t, center.dy)
      ..close();
    canvas.drawPath(triangle, Paint()..color = Colors.white);
  }

  /// Draws the active snap guides (center/edge alignment) as thin accent
  /// lines spanning the artboard.
  void _paintGuides(Canvas canvas) {
    if (guides.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFFEC4899) // pink, distinct from the blue selection
      ..strokeWidth = 1;
    final w = document.width * scale;
    final h = document.height * scale;
    for (final guide in guides) {
      if (guide.axis == GuideAxis.vertical) {
        final x = guide.position * scale;
        canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
      } else {
        final y = guide.position * scale;
        canvas.drawLine(Offset(0, y), Offset(w, y), paint);
      }
    }
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
        !setEquals(oldDelegate.selectedLayerIds, selectedLayerIds) ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.marquee != marquee ||
        !listEquals(oldDelegate.guides, guides);
  }
}
