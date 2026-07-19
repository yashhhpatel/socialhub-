import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/canvas_layer.dart';

/// True if `point` (artboard space) falls within `layer`'s bounds,
/// accounting for rotation. Works by transforming the point into the
/// layer's own unrotated local space (translate to origin at the
/// layer's center, rotate by the INVERSE of the layer's rotation,
/// translate back) rather than trying to rotate the layer's bounds
/// themselves — this is the standard technique and keeps the bounds
/// check itself a simple axis-aligned rectangle test either way.
bool layerContainsPoint(CanvasLayer layer, Offset point) {
  final center = layer.center;
  final relative = point - center;

  if (layer.rotationDegrees == 0) {
    // Skip the trig entirely for the common unrotated case.
    final local = relative + center;
    return _withinBounds(layer, local);
  }

  final radians = -layer.rotationDegrees * math.pi / 180;
  final cosA = math.cos(radians);
  final sinA = math.sin(radians);
  final rotated = Offset(
    relative.dx * cosA - relative.dy * sinA,
    relative.dx * sinA + relative.dy * cosA,
  );
  final local = rotated + center;

  return _withinBounds(layer, local);
}

bool _withinBounds(CanvasLayer layer, Offset point) {
  return point.dx >= layer.x &&
      point.dx <= layer.x + layer.width &&
      point.dy >= layer.y &&
      point.dy <= layer.y + layer.height;
}

/// Returns the TOPMOST layer containing `point`, or null if none does.
/// Iterates in reverse — the last layer in the list is the top of the
/// visual stack (see CanvasDocument's doc comment) and should win a hit
/// test over anything beneath it.
CanvasLayer? hitTestLayers(List<CanvasLayer> layers, Offset point) {
  for (final layer in layers.reversed) {
    if (layerContainsPoint(layer, point)) return layer;
  }
  return null;
}
