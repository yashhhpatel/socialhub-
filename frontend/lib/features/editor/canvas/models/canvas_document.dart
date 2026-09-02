import 'package:flutter/material.dart';

import 'canvas_layer.dart';

/// The artboard being edited. `layers` is painted in list order — index 0
/// is the bottom of the stack, the last element is the topmost (and
/// therefore the one hit-tested first — see hit_testing.dart).
class CanvasDocument {
  const CanvasDocument({
    required this.width,
    required this.height,
    this.layers = const [],
    this.backgroundColor = const Color(0xFFFFFFFF),
  });

  final double width;
  final double height;
  final List<CanvasLayer> layers;

  /// Solid fill painted behind every layer. Defaults to white (what the
  /// artboard has always rendered), so older saved documents load unchanged.
  final Color backgroundColor;

  CanvasDocument copyWithLayers(List<CanvasLayer> newLayers) => CanvasDocument(
        width: width,
        height: height,
        layers: newLayers,
        backgroundColor: backgroundColor,
      );

  /// Changes the artboard itself (size and/or background) while keeping every
  /// layer. Used by the "Resize" presets and the canvas background control.
  CanvasDocument copyWith({
    double? width,
    double? height,
    Color? backgroundColor,
  }) =>
      CanvasDocument(
        width: width ?? this.width,
        height: height ?? this.height,
        layers: layers,
        backgroundColor: backgroundColor ?? this.backgroundColor,
      );

  /// The exact payload sent as `canvasJson` to `PATCH /content/assets/:id`
  /// — width/height/layers, matching the backend's CanvasJsonDto contract
  /// (see backend dto/canvas-json.dto.ts).
  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        // ignore: deprecated_member_use — `.value` for 3.22 compat (see layer).
        'backgroundColor': backgroundColor.value,
        'layers': [for (final layer in layers) layer.toJson()],
      };

  /// Inverse of [toJson] — used when reopening a saved asset so the
  /// editor reloads exactly the document that was last autosaved.
  factory CanvasDocument.fromJson(Map<String, dynamic> json) => CanvasDocument(
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        backgroundColor: json['backgroundColor'] is int
            ? Color(json['backgroundColor'] as int)
            : const Color(0xFFFFFFFF),
        layers: [
          for (final layer in (json['layers'] as List<dynamic>? ?? []))
            CanvasLayer.fromJson(layer as Map<String, dynamic>),
        ],
      );
}
