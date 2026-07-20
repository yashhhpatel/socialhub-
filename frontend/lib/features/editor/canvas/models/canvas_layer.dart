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

  /// Every subtype must implement this. Covers every field the property
  /// panel (Milestone 3.4) edits that's common to ALL layer types —
  /// position, size, rotation, opacity. Subtype-specific fields (color,
  /// image URL, text content) each have their own dedicated copyWith*
  /// method instead (see below) rather than being crammed into one
  /// enormous param list here.
  ///
  /// Named, nullable params: passing nothing for a field leaves it
  /// unchanged — CanvasController.updateSelectedLayerGeometry (see
  /// canvas_controller.dart) relies on this so a property panel field
  /// edit (e.g. just X) doesn't require re-specifying every other value.
  CanvasLayer copyWithGeometry({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
  });
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
  ImageCanvasLayer copyWithGeometry({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
  }) =>
      ImageCanvasLayer(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        opacity: opacity ?? this.opacity,
        imageUrl: imageUrl,
      );

  ImageCanvasLayer copyWithImageUrl(String newImageUrl) => ImageCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        imageUrl: newImageUrl,
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
  TextCanvasLayer copyWithGeometry({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
  }) =>
      TextCanvasLayer(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        opacity: opacity ?? this.opacity,
        text: text,
        fontSize: fontSize,
        color: color,
        fontFamily: fontFamily,
      );

  TextCanvasLayer copyWithColor(Color newColor) => TextCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        text: text,
        fontSize: fontSize,
        color: newColor,
        fontFamily: fontFamily,
      );

  TextCanvasLayer copyWithText(String newText) => TextCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        text: newText,
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
  ShapeCanvasLayer copyWithGeometry({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
  }) =>
      ShapeCanvasLayer(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        opacity: opacity ?? this.opacity,
        shapeKind: shapeKind,
        fillColor: fillColor,
      );

  ShapeCanvasLayer copyWithFillColor(Color newFillColor) => ShapeCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        shapeKind: shapeKind,
        fillColor: newFillColor,
      );
}
