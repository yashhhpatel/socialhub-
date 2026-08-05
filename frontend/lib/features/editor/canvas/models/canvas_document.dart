import 'canvas_layer.dart';

/// The artboard being edited. `layers` is painted in list order — index 0
/// is the bottom of the stack, the last element is the topmost (and
/// therefore the one hit-tested first — see hit_testing.dart).
class CanvasDocument {
  const CanvasDocument({
    required this.width,
    required this.height,
    this.layers = const [],
  });

  final double width;
  final double height;
  final List<CanvasLayer> layers;

  CanvasDocument copyWithLayers(List<CanvasLayer> newLayers) => CanvasDocument(
        width: width,
        height: height,
        layers: newLayers,
      );

  /// The exact payload sent as `canvasJson` to `PATCH /content/assets/:id`
  /// — width/height/layers, matching the backend's CanvasJsonDto contract
  /// (see backend dto/canvas-json.dto.ts).
  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'layers': [for (final layer in layers) layer.toJson()],
      };

  /// Inverse of [toJson] — used when reopening a saved asset so the
  /// editor reloads exactly the document that was last autosaved.
  factory CanvasDocument.fromJson(Map<String, dynamic> json) => CanvasDocument(
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        layers: [
          for (final layer in (json['layers'] as List<dynamic>? ?? []))
            CanvasLayer.fromJson(layer as Map<String, dynamic>),
        ],
      );
}
