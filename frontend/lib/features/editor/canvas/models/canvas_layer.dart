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

  /// Serializes to the persisted canvas-JSON shape sent to
  /// `PATCH /content/assets/:id` (Milestone 3.5 autosave).
  ///
  /// The backend deliberately validates `layers` only as an array of
  /// unknown-shaped entries (see backend dto/canvas-json.dto.ts) — the
  /// layer schema is the editor's contract to own, which is exactly what
  /// this method and [fromJson] define. Keep the two in lockstep: every
  /// field written here must be read back there, or a reload silently
  /// drops user work.
  Map<String, dynamic> toJson();

  /// Fields shared by every subtype. Subtype [toJson] implementations
  /// spread this and add their own — so adding a field to the base class
  /// can't be forgotten in three separate places.
  Map<String, dynamic> geometryJson(String type) => {
        'type': type,
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotationDegrees': rotationDegrees,
        'opacity': opacity,
      };

  /// Rebuilds a layer from persisted JSON, dispatching on the `type`
  /// discriminator written by [toJson].
  ///
  /// Throws [FormatException] on an unknown type rather than skipping the
  /// layer: silently dropping one is the worse failure — the user would
  /// reload a design and find part of it simply gone, with nothing
  /// indicating why. A loud failure is recoverable; a silent one isn't.
  static CanvasLayer fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    return switch (type) {
      'image' => ImageCanvasLayer(
          id: json['id'] as String,
          x: _double(json['x']),
          y: _double(json['y']),
          width: _double(json['width']),
          height: _double(json['height']),
          rotationDegrees: _double(json['rotationDegrees']),
          opacity: _double(json['opacity'], fallback: 1),
          imageUrl: json['imageUrl'] as String,
        ),
      'text' => TextCanvasLayer(
          id: json['id'] as String,
          x: _double(json['x']),
          y: _double(json['y']),
          width: _double(json['width']),
          height: _double(json['height']),
          rotationDegrees: _double(json['rotationDegrees']),
          opacity: _double(json['opacity'], fallback: 1),
          text: json['text'] as String,
          fontSize: _double(json['fontSize'], fallback: 24),
          color: Color(json['color'] as int),
          fontFamily: json['fontFamily'] as String?,
        ),
      'shape' => ShapeCanvasLayer(
          id: json['id'] as String,
          x: _double(json['x']),
          y: _double(json['y']),
          width: _double(json['width']),
          height: _double(json['height']),
          rotationDegrees: _double(json['rotationDegrees']),
          opacity: _double(json['opacity'], fallback: 1),
          shapeKind: ShapeKind.values.byName(json['shapeKind'] as String),
          fillColor: Color(json['fillColor'] as int),
        ),
      'video' => VideoCanvasLayer(
          id: json['id'] as String,
          x: _double(json['x']),
          y: _double(json['y']),
          width: _double(json['width']),
          height: _double(json['height']),
          rotationDegrees: _double(json['rotationDegrees']),
          opacity: _double(json['opacity'], fallback: 1),
          videoUrl: json['videoUrl'] as String,
          posterUrl: json['posterUrl'] as String?,
          trimStartSeconds: _double(json['trimStartSeconds']),
          trimEndSeconds:
              json['trimEndSeconds'] == null ? null : _double(json['trimEndSeconds']),
        ),
      _ => throw FormatException('Unknown canvas layer type: $type'),
    };
  }

  /// JSON numbers arrive as `int` whenever they happen to be whole (1080,
  /// not 1080.0), so a blind `as double` cast throws on perfectly valid
  /// persisted data. Always parse through this.
  static double _double(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return fallback;
  }
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

  @override
  Map<String, dynamic> toJson() => {
        ...geometryJson('image'),
        'imageUrl': imageUrl,
      };
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

  TextCanvasLayer copyWithFontFamily(String? newFontFamily) => TextCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        text: text,
        fontSize: fontSize,
        color: color,
        fontFamily: newFontFamily,
      );

  TextCanvasLayer copyWithFontSize(double newFontSize) => TextCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        text: text,
        fontSize: newFontSize,
        color: color,
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

  @override
  Map<String, dynamic> toJson() => {
        ...geometryJson('text'),
        'text': text,
        'fontSize': fontSize,
        // `.value`, not `.toARGB32()` — the latter only exists from
        // Flutter 3.27, and pubspec.yaml declares a floor of 3.22.0.
        // Using it made this file uncompilable on the project's own
        // minimum supported SDK. `.value` works across the whole
        // supported range (it carries a deprecation notice on newer
        // SDKs, but that's an info, not a build failure).
        // ignore: deprecated_member_use
        'color': color.value,
        'fontFamily': fontFamily,
      };
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

  @override
  Map<String, dynamic> toJson() => {
        ...geometryJson('shape'),
        'shapeKind': shapeKind.name,
        // See the note on TextCanvasLayer.toJson — `.value` for 3.22
        // compatibility.
        // ignore: deprecated_member_use
        'fillColor': fillColor.value,
      };
}

/// A video layer (Milestone 9.1).
///
/// A CustomPainter can't play video, so on the canvas this renders its
/// [posterUrl] (a still frame / thumbnail) with a play badge — enough to
/// position and size it like any other layer, and what the exported master
/// render captures. Live playback and the actual transcode/trim happen off
/// the canvas (trim is applied by the backend pipeline in Milestone 9.2,
/// driven by [trimStartSeconds]/[trimEndSeconds]).
class VideoCanvasLayer extends CanvasLayer {
  const VideoCanvasLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotationDegrees,
    super.opacity,
    required this.videoUrl,
    this.posterUrl,
    this.trimStartSeconds = 0,
    this.trimEndSeconds,
  });

  final String videoUrl;

  /// Still frame shown on the canvas and baked into the master render.
  final String? posterUrl;

  /// Trim window, in seconds. [trimEndSeconds] null means "to the end" —
  /// the real duration isn't known until the video loads/transcodes, so the
  /// end is left open rather than guessed.
  final double trimStartSeconds;
  final double? trimEndSeconds;

  @override
  VideoCanvasLayer copyWithGeometry({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
  }) =>
      VideoCanvasLayer(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        opacity: opacity ?? this.opacity,
        videoUrl: videoUrl,
        posterUrl: posterUrl,
        trimStartSeconds: trimStartSeconds,
        trimEndSeconds: trimEndSeconds,
      );

  /// Sets the trim window. Passing nothing for a bound leaves it unchanged;
  /// pass `clearEnd: true` to reset the end back to "to the end".
  VideoCanvasLayer copyWithTrim({
    double? trimStartSeconds,
    double? trimEndSeconds,
    bool clearEnd = false,
  }) =>
      VideoCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        videoUrl: videoUrl,
        posterUrl: posterUrl,
        trimStartSeconds: trimStartSeconds ?? this.trimStartSeconds,
        trimEndSeconds: clearEnd ? null : (trimEndSeconds ?? this.trimEndSeconds),
      );

  @override
  Map<String, dynamic> toJson() => {
        ...geometryJson('video'),
        'videoUrl': videoUrl,
        'posterUrl': posterUrl,
        'trimStartSeconds': trimStartSeconds,
        'trimEndSeconds': trimEndSeconds,
      };
}
