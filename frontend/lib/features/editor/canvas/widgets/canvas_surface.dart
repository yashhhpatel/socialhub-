import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/canvas_document.dart';
import '../rendering/canvas_image_cache.dart';
import '../rendering/canvas_painter.dart';
import '../state/canvas_controller.dart';

/// The interactive editor canvas. Owns:
/// - Fitting the artboard into available space (BoxFit.contain-style
///   scale + centering offset — "letterboxing"), recomputed every build
///   via LayoutBuilder so resizing the window/panel just works.
/// - Converting gesture coordinates (widget-local pixels) into artboard
///   space before handing them to CanvasController, which knows nothing
///   about screen pixels at all — it only ever sees artboard units.
/// - Owning the CanvasImageCache's lifecycle (created once per widget
///   instance, disposed with it) — see that class's doc comment for why
///   this isn't a Riverpod provider.
///
/// Gesture design: onPanStart both selects (hit-tests at the gesture's
/// start position) AND is the beginning of a potential drag — a single
/// composed gesture rather than separate tap/drag recognizers, which is
/// the standard pattern for design-tool canvases (touch down selects
/// AND is ready to drag in one motion).
class CanvasSurface extends ConsumerStatefulWidget {
  const CanvasSurface({super.key, required this.document});

  final CanvasDocument document;

  @override
  ConsumerState<CanvasSurface> createState() => _CanvasSurfaceState();
}

class _CanvasSurfaceState extends ConsumerState<CanvasSurface> {
  final CanvasImageCache _imageCache = CanvasImageCache();

  @override
  void dispose() {
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = canvasControllerProvider(widget.document);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / state.document.width,
          constraints.maxHeight / state.document.height,
        );
        final artboardWidthPx = state.document.width * scale;
        final artboardHeightPx = state.document.height * scale;
        final letterboxOffset = Offset(
          (constraints.maxWidth - artboardWidthPx) / 2,
          (constraints.maxHeight - artboardHeightPx) / 2,
        );

        Offset toArtboardSpace(Offset widgetLocalPoint) {
          return (widgetLocalPoint - letterboxOffset) / scale;
        }

        return GestureDetector(
          onPanStart: (details) {
            controller.selectLayerAt(toArtboardSpace(details.localPosition));
          },
          onPanUpdate: (details) {
            // details.delta is already a pixel delta, not an absolute
            // position — dividing by scale converts it to an artboard-
            // space delta directly, no letterboxOffset subtraction
            // needed (offsets cancel out for a delta between two points).
            controller.moveSelectedLayerBy(details.delta / scale);
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: CanvasPainter(
              document: state.document,
              selectedLayerId: state.selectedLayerId,
              scale: scale,
              offset: letterboxOffset,
              imageCache: _imageCache,
            ),
          ),
        );
      },
    );
  }
}
