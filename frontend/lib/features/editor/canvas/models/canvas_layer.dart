import 'package:flutter/material.dart';

/// Base type for anything paintable on the canvas. `sealed` so every
/// switch over a CanvasLayer (see canvas_painter.dart) is exhaustive at
/// compile time — adding a 4th layer type later is a compile error
/// everywhere it isn't handled, not a silent runtime gap.
///
/// All coordinates (x/y/width/height) are in ARTBOARD space, not widget/
/// screen pixels — CanvasSurface owns the scale/offset conversion
/// between the two (see widgets/canvas_surface.dart).
sealed class CanvasLayer {
  const CanvasLayer({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotationDegrees = 0,
    this.opacity = 1.0,
  });

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotationDegrees;
  final double opacity;

  Offset get center => Offset(x + width / 2, y + height / 2);

  /// Every subtype must implement this — used by CanvasController's
  /// drag handling, kept on the base type so the controller never needs
  /// to know which concrete subtype it's moving.
  CanvasLayer copyWithPosition(double newX, double newY);
}

class ImageCanvasLayer extends CanvasLayer {
  const ImageCanvasLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotationDegrees,
    super.opacity,
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  ImageCanvasLayer copyWithPosition(double newX, double newY) => ImageCanvasLayer(
        id: id,
        x: newX,
        y: newY,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        imageUrl: imageUrl,
      );
}

class TextCanvasLayer extends CanvasLayer {
  const TextCanvasLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotationDegrees,
    super.opacity,
    required this.text,
    this.fontSize = 24,
    this.color = const Color(0xFF111827),
    this.fontFamily,
  });

  final String text;
  final double fontSize;
  final Color color;
  final String? fontFamily;

  @override
  TextCanvasLayer copyWithPosition(double newX, double newY) => TextCanvasLayer(
        id: id,
        x: newX,
        y: newY,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        text: text,
        fontSize: fontSize,
        color: color,
        fontFamily: fontFamily,
      );
}

enum ShapeKind { rectangle, ellipse }

class ShapeCanvasLayer extends CanvasLayer {
  const ShapeCanvasLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotationDegrees,
    super.opacity,
    required this.shapeKind,
    this.fillColor = const Color(0xFF3B82F6),
  });

  final ShapeKind shapeKind;
  final Color fillColor;

  @override
  ShapeCanvasLayer copyWithPosition(double newX, double newY) => ShapeCanvasLayer(
        id: id,
        x: newX,
        y: newY,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        shapeKind: shapeKind,
        fillColor: fillColor,
      );
}
