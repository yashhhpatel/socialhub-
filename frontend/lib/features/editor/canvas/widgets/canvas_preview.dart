import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/canvas_document.dart';
import '../rendering/canvas_image_cache.dart';
import '../rendering/canvas_painter.dart';

/// A read-only, non-interactive render of a [CanvasDocument], fit to the
/// available space (letterboxed, aspect-ratio preserved). Reuses the editor's
/// [CanvasPainter] so a preview looks exactly like the real canvas, and owns a
/// [CanvasImageCache] so image layers load + repaint here too.
///
/// Unlike CanvasSurface this has no gestures, selection or controller — it's
/// purely for showing a design (e.g. a template/marketplace detail preview).
class CanvasPreview extends StatefulWidget {
  const CanvasPreview({super.key, required this.document});

  final CanvasDocument document;

  @override
  State<CanvasPreview> createState() => _CanvasPreviewState();
}

class _CanvasPreviewState extends State<CanvasPreview> {
  final CanvasImageCache _imageCache = CanvasImageCache();

  @override
  void dispose() {
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / widget.document.width,
          constraints.maxHeight / widget.document.height,
        );
        final wPx = widget.document.width * scale;
        final hPx = widget.document.height * scale;
        final offset = Offset(
          (constraints.maxWidth - wPx) / 2,
          (constraints.maxHeight - hPx) / 2,
        );
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: CanvasPainter(
            document: widget.document,
            selectedLayerId: null,
            scale: scale,
            offset: offset,
            imageCache: _imageCache,
          ),
        );
      },
    );
  }
}
