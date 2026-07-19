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
}
