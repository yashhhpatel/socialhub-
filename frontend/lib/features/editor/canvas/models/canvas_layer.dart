import 'package:flutter/material.dart';

/// Base type for anything paintable on the canvas. `sealed` so every
/// switch over a CanvasLayer (see canvas_painter.dart) is exhaustive at
/// compile time — adding a 5th layer type later is a compile error
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
    this.locked = false,
    this.hidden = false,
  });

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotationDegrees;
  final double opacity;

  /// Locked layers can't be selected or moved on the canvas (only toggled
  /// back from the Layers panel), so a finished background stays put.
  final bool locked;

  /// Hidden layers aren't painted or hit-tested, but stay in the document.
  final bool hidden;

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

  /// Toggles the lock/hide flags, preserving everything else.
  CanvasLayer copyWithFlags({bool? locked, bool? hidden});

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
        'locked': locked,
        'hidden': hidden,
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
    final locked = json['locked'] == true;
    final hidden = json['hidden'] == true;
    return switch (type) {
      'image' => ImageCanvasLayer(
          id: json['id'] as String,
          x: _double(json['x']),
          y: _double(json['y']),
          width: _double(json['width']),
          height: _double(json['height']),
          rotationDegrees: _double(json['rotationDegrees']),
          opacity: _double(json['opacity'], fallback: 1),
          locked: locked,
          hidden: hidden,
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
          locked: locked,
          hidden: hidden,
          text: json['text'] as String,
          fontSize: _double(json['fontSize'], fallback: 24),
          color: Color(json['color'] as int),
          fontFamily: json['fontFamily'] as String?,
          bold: json['bold'] == true,
          italic: json['italic'] == true,
          align: _align(json['align']),
          lineHeight: _double(json['lineHeight'], fallback: 1.2),
        ),
      'shape' => ShapeCanvasLayer(
          id: json['id'] as String,
          x: _double(json['x']),
          y: _double(json['y']),
          width: _double(json['width']),
          height: _double(json['height']),
          rotationDegrees: _double(json['rotationDegrees']),
          opacity: _double(json['opacity'], fallback: 1),
          locked: locked,
          hidden: hidden,
          shapeKind: ShapeKind.values.byName(json['shapeKind'] as String),
          fillColor: Color(json['fillColor'] as int),
          strokeColor:
              json['strokeColor'] is int ? Color(json['strokeColor'] as int) : null,
          strokeWidth: _double(json['strokeWidth']),
          cornerRadius: _double(json['cornerRadius']),
        ),
      'video' => VideoCanvasLayer(
          id: json['id'] as String,
          x: _double(json['x']),
          y: _double(json['y']),
          width: _double(json['width']),
          height: _double(json['height']),
          rotationDegrees: _double(json['rotationDegrees']),
          opacity: _double(json['opacity'], fallback: 1),
          locked: locked,
          hidden: hidden,
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

  static TextAlign _align(Object? value) {
    if (value is String) {
      for (final a in TextAlign.values) {
        if (a.name == value) return a;
      }
    }
    return TextAlign.left;
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
    super.locked,
    super.hidden,
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
        locked: locked,
        hidden: hidden,
        imageUrl: imageUrl,
      );

  @override
  ImageCanvasLayer copyWithFlags({bool? locked, bool? hidden}) =>
      ImageCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        locked: locked ?? this.locked,
        hidden: hidden ?? this.hidden,
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
        locked: locked,
        hidden: hidden,
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
    super.locked,
    super.hidden,
    required this.text,
    this.fontSize = 24,
    this.color = const Color(0xFF111827),
    this.fontFamily,
    this.bold = false,
    this.italic = false,
    this.align = TextAlign.left,
    this.lineHeight = 1.2,
  });

  final String text;
  final double fontSize;
  final Color color;
  final String? fontFamily;
  final bool bold;
  final bool italic;
  final TextAlign align;
  final double lineHeight;

  @override
  TextCanvasLayer copyWithGeometry({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
  }) =>
      _copy(
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
      );

  @override
  TextCanvasLayer copyWithFlags({bool? locked, bool? hidden}) =>
      _copy(locked: locked, hidden: hidden);

  TextCanvasLayer copyWithColor(Color newColor) => _copy(color: newColor);
  TextCanvasLayer copyWithFontFamily(String? newFontFamily) =>
      _copy(fontFamily: newFontFamily, clearFontFamily: newFontFamily == null);
  TextCanvasLayer copyWithFontSize(double newFontSize) =>
      _copy(fontSize: newFontSize);
  TextCanvasLayer copyWithText(String newText) => _copy(text: newText);

  /// Batched text-format edit (bold/italic/alignment/line-height/font).
  TextCanvasLayer copyWithTextFormat({
    bool? bold,
    bool? italic,
    TextAlign? align,
    double? lineHeight,
    String? fontFamily,
  }) =>
      _copy(
        bold: bold,
        italic: italic,
        align: align,
        lineHeight: lineHeight,
        fontFamily: fontFamily,
      );

  /// One private reconstruction so every copyWith* keeps ALL fields — a
  /// missed field here would silently reset a layer's styling on an edit.
  TextCanvasLayer _copy({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
    bool? locked,
    bool? hidden,
    String? text,
    double? fontSize,
    Color? color,
    String? fontFamily,
    bool clearFontFamily = false,
    bool? bold,
    bool? italic,
    TextAlign? align,
    double? lineHeight,
  }) =>
      TextCanvasLayer(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        opacity: opacity ?? this.opacity,
        locked: locked ?? this.locked,
        hidden: hidden ?? this.hidden,
        text: text ?? this.text,
        fontSize: fontSize ?? this.fontSize,
        color: color ?? this.color,
        fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        align: align ?? this.align,
        lineHeight: lineHeight ?? this.lineHeight,
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
        'bold': bold,
        'italic': italic,
        'align': align.name,
        'lineHeight': lineHeight,
      };
}

enum ShapeKind { rectangle, ellipse, triangle, star, diamond }

class ShapeCanvasLayer extends CanvasLayer {
  const ShapeCanvasLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotationDegrees,
    super.opacity,
    super.locked,
    super.hidden,
    required this.shapeKind,
    this.fillColor = const Color(0xFF3B82F6),
    this.strokeColor,
    this.strokeWidth = 0,
    this.cornerRadius = 0,
  });

  final ShapeKind shapeKind;
  final Color fillColor;

  /// Optional border. Null (or a zero [strokeWidth]) means no border drawn.
  final Color? strokeColor;
  final double strokeWidth;

  /// Rounded-corner radius, for rectangles (ignored by ellipses).
  final double cornerRadius;

  @override
  ShapeCanvasLayer copyWithGeometry({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
  }) =>
      _copy(
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
      );

  @override
  ShapeCanvasLayer copyWithFlags({bool? locked, bool? hidden}) =>
      _copy(locked: locked, hidden: hidden);

  ShapeCanvasLayer copyWithFillColor(Color newFillColor) =>
      _copy(fillColor: newFillColor);

  /// Batched border/corner edit. Pass [clearStroke] to remove the border.
  ShapeCanvasLayer copyWithShapeStyle({
    Color? strokeColor,
    double? strokeWidth,
    double? cornerRadius,
    bool clearStroke = false,
  }) =>
      _copy(
        strokeColor: strokeColor,
        clearStroke: clearStroke,
        strokeWidth: strokeWidth,
        cornerRadius: cornerRadius,
      );

  ShapeCanvasLayer _copy({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotationDegrees,
    double? opacity,
    bool? locked,
    bool? hidden,
    Color? fillColor,
    Color? strokeColor,
    bool clearStroke = false,
    double? strokeWidth,
    double? cornerRadius,
  }) =>
      ShapeCanvasLayer(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        opacity: opacity ?? this.opacity,
        locked: locked ?? this.locked,
        hidden: hidden ?? this.hidden,
        shapeKind: shapeKind,
        fillColor: fillColor ?? this.fillColor,
        strokeColor: clearStroke ? null : (strokeColor ?? this.strokeColor),
        strokeWidth: strokeWidth ?? this.strokeWidth,
        cornerRadius: cornerRadius ?? this.cornerRadius,
      );

  @override
  Map<String, dynamic> toJson() => {
        ...geometryJson('shape'),
        'shapeKind': shapeKind.name,
        // See the note on TextCanvasLayer.toJson — `.value` for 3.22
        // compatibility.
        // ignore: deprecated_member_use
        'fillColor': fillColor.value,
        // ignore: deprecated_member_use
        'strokeColor': strokeColor?.value,
        'strokeWidth': strokeWidth,
        'cornerRadius': cornerRadius,
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
    super.locked,
    super.hidden,
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
        locked: locked,
        hidden: hidden,
        videoUrl: videoUrl,
        posterUrl: posterUrl,
        trimStartSeconds: trimStartSeconds,
        trimEndSeconds: trimEndSeconds,
      );

  @override
  VideoCanvasLayer copyWithFlags({bool? locked, bool? hidden}) =>
      VideoCanvasLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
        opacity: opacity,
        locked: locked ?? this.locked,
        hidden: hidden ?? this.hidden,
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
        locked: locked,
        hidden: hidden,
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
