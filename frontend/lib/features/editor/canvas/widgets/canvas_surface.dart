import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hit_testing.dart';
import '../models/canvas_document.dart';
import '../models/canvas_layer.dart';
import '../rendering/canvas_image_cache.dart';
import '../rendering/canvas_painter.dart';
import '../state/canvas_controller.dart';
import '../state/canvas_editor_state.dart';

/// The interactive editor canvas. Owns:
/// - Fitting the artboard into available space (BoxFit.contain-style
///   scale + centering), recomputed every build via LayoutBuilder.
/// - A user zoom factor on top of that fit scale, with a floating zoom bar;
///   when zoomed past the viewport the artboard scrolls.
/// - Snap guides: while dragging, the layer snaps to the artboard's centre
///   and edges, with pink guide lines shown at the snap.
/// - Converting gesture coordinates into artboard space before handing them
///   to CanvasController, which only ever sees artboard units.
/// - Owning the CanvasImageCache's lifecycle.
class CanvasSurface extends ConsumerStatefulWidget {
  const CanvasSurface({super.key, required this.document});

  final CanvasDocument document;

  @override
  ConsumerState<CanvasSurface> createState() => _CanvasSurfaceState();
}

class _CanvasSurfaceState extends ConsumerState<CanvasSurface> {
  final CanvasImageCache _imageCache = CanvasImageCache();

  /// User zoom multiplier on top of the fit scale. 1.0 == fit-to-viewport.
  double _zoom = 1.0;
  static const double _minZoom = 0.25;
  static const double _maxZoom = 4.0;

  /// Active snap guides for the in-flight drag; empty when not snapping.
  List<CanvasGuide> _guides = const [];

  /// When a drag started on a resize handle / rotate knob, the active mode for
  /// the rest of that drag (so a resize doesn't turn into a move mid-gesture).
  ResizeHandle? _activeHandle;
  bool _rotating = false;

  /// Marquee-selection drag: the artboard-space start point and the live rect.
  Offset? _marqueeStart;
  Rect? _marquee;

  /// The text layer being edited inline, and the field's controller.
  String? _editingLayerId;
  final TextEditingController _editController = TextEditingController();

  @override
  void dispose() {
    _imageCache.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _setZoom(double zoom) =>
      setState(() => _zoom = zoom.clamp(_minZoom, _maxZoom));

  /// Double-clicking a text layer edits its content INLINE — an overlay
  /// TextField appears over the layer (see [build]); only text layers open it.
  void _editTextAt(Offset artboardPoint) {
    final provider = canvasControllerProvider(widget.document);
    final controller = ref.read(provider.notifier);
    final hit = hitTestLayers(ref.read(provider).document.layers, artboardPoint);
    if (hit is! TextCanvasLayer) return;
    controller.selectLayerById(hit.id);
    _editController.text = hit.text;
    setState(() => _editingLayerId = hit.id);
  }

  /// Commits the inline edit back to the layer and closes the overlay.
  void _commitEdit(CanvasController controller) {
    if (_editingLayerId == null) return;
    controller.updateSelectedLayerText(_editController.text);
    setState(() => _editingLayerId = null);
  }

  /// The layer currently being edited, looked up fresh from state.
  TextCanvasLayer? _editingLayer(CanvasEditorState state) {
    final id = _editingLayerId;
    if (id == null) return null;
    for (final l in state.document.layers) {
      if (l.id == id && l is TextCanvasLayer) return l;
    }
    return null;
  }

  /// Decides at drag-start whether this gesture resizes (a handle), rotates
  /// (the knob), or selects+moves. A resize/rotate keeps the current
  /// selection; a plain drag hit-tests and selects under the pointer.
  void _onPanStart(
    DragStartDetails details,
    CanvasController controller,
    CanvasEditorState state,
    double effScale,
  ) {
    final local = details.localPosition;
    final artPoint = local / effScale;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final selected = _selectedLayer(state); // non-null only for a single selection
    if (selected != null && !selected.hidden && !selected.locked) {
      // Rotate knob (works at any rotation).
      if ((local - rotateHandleCenter(selected, effScale)).distance <=
          kHandleSize) {
        _rotating = true;
        controller.beginInteraction();
        return;
      }
      // Resize handles (only offered for an unrotated layer).
      if (selected.rotationDegrees == 0) {
        for (final entry in resizeHandleCenters(selected, effScale).entries) {
          if ((local - entry.value).distance <= kHandleSize) {
            _activeHandle = entry.key;
            controller.beginInteraction();
            return;
          }
        }
      }
    }

    final hit = hitTestLayers(state.document.layers, artPoint);
    if (hit != null) {
      if (shift) {
        controller.toggleLayerSelection(hit.id);
      } else {
        controller.selectLayerAt(artPoint); // keeps a multi selection to drag
      }
      controller.beginInteraction(); // ready to move
      return;
    }

    // Empty space → marquee-select. Plain click clears first; Shift keeps the
    // existing selection (the marquee replaces it live during the drag).
    _marqueeStart = artPoint;
    if (!shift) controller.clearSelection();
    setState(() => _marquee = Rect.fromPoints(artPoint, artPoint));
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    CanvasController controller,
    CanvasEditorState state,
    CanvasDocument doc,
    double effScale,
  ) {
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (_marqueeStart != null) {
      final cur = details.localPosition / effScale;
      final rect = Rect.fromPoints(_marqueeStart!, cur);
      controller.selectLayersInRect(rect);
      setState(() => _marquee = rect);
      return;
    }
    if (_activeHandle != null) {
      controller.resizeSelectedByHandle(
        _activeHandle!,
        details.delta / effScale,
        lockAspect: shift,
      );
      return;
    }
    if (_rotating) {
      final sel = _selectedLayer(state);
      if (sel == null) return;
      final c = Offset(
        (sel.x + sel.width / 2) * effScale,
        (sel.y + sel.height / 2) * effScale,
      );
      final local = details.localPosition;
      var deg = math.atan2(local.dy - c.dy, local.dx - c.dx) * 180 / math.pi + 90;
      deg %= 360;
      if (deg < 0) deg += 360;
      if (shift) deg = (deg / 15).round() * 15; // snap to 15° with Shift
      controller.updateSelectedLayerGeometry(rotationDegrees: deg.roundToDouble());
      return;
    }
    _moveWithSnap(details, controller, doc, effScale, _selectedLayer(state));
  }

  /// Applies drag delta. For a single selection it snaps to the artboard
  /// (centre + edges) with guides; for a multi selection (where [selected] is
  /// null but layers are selected) it just moves them all, no snap.
  void _moveWithSnap(
    DragUpdateDetails details,
    CanvasController controller,
    CanvasDocument doc,
    double effScale,
    CanvasLayer? selected,
  ) {
    if (selected == null) {
      // No single selection: move the whole (possibly multi) selection plainly.
      controller.moveSelectedLayerBy(details.delta / effScale);
      return;
    }
    if (selected.locked) return;

    final rawDx = details.delta.dx / effScale;
    final rawDy = details.delta.dy / effScale;
    var newX = selected.x + rawDx;
    var newY = selected.y + rawDy;

    // Snap threshold in artboard units (~8 screen px).
    final threshold = 8 / effScale;
    final guides = <CanvasGuide>[];

    // Horizontal snaps (adjust X): left edge, centre, right edge.
    final centerX = newX + selected.width / 2;
    if ((newX).abs() <= threshold) {
      newX = 0;
      guides.add(const CanvasGuide(GuideAxis.vertical, 0));
    } else if ((centerX - doc.width / 2).abs() <= threshold) {
      newX = doc.width / 2 - selected.width / 2;
      guides.add(CanvasGuide(GuideAxis.vertical, doc.width / 2));
    } else if ((newX + selected.width - doc.width).abs() <= threshold) {
      newX = doc.width - selected.width;
      guides.add(CanvasGuide(GuideAxis.vertical, doc.width));
    }

    // Vertical snaps (adjust Y): top edge, centre, bottom edge.
    final centerY = newY + selected.height / 2;
    if ((newY).abs() <= threshold) {
      newY = 0;
      guides.add(const CanvasGuide(GuideAxis.horizontal, 0));
    } else if ((centerY - doc.height / 2).abs() <= threshold) {
      newY = doc.height / 2 - selected.height / 2;
      guides.add(CanvasGuide(GuideAxis.horizontal, doc.height / 2));
    } else if ((newY + selected.height - doc.height).abs() <= threshold) {
      newY = doc.height - selected.height;
      guides.add(CanvasGuide(GuideAxis.horizontal, doc.height));
    }

    controller.moveSelectedLayerBy(Offset(newX - selected.x, newY - selected.y));
    if (guides.length != _guides.length ||
        !guides.every(_guides.contains)) {
      setState(() => _guides = guides);
    }
  }

  void _endDrag(CanvasController controller) {
    controller.endInteraction();
    _activeHandle = null;
    _rotating = false;
    _marqueeStart = null;
    if (_guides.isNotEmpty || _marquee != null) {
      setState(() {
        _guides = const [];
        _marquee = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = canvasControllerProvider(widget.document);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final doc = state.document;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth;
        final vh = constraints.maxHeight;
        final fitScale = math.min(vw / doc.width, vh / doc.height);
        final effScale = fitScale * _zoom;
        final artW = doc.width * effScale;
        final artH = doc.height * effScale;

        Offset toArtboardSpace(Offset local) => local / effScale;

        final editing = _editingLayer(state);
        final content = SizedBox(
          width: artW,
          height: artH,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onDoubleTapDown: (d) =>
                      _editTextAt(toArtboardSpace(d.localPosition)),
                  onPanStart: (d) =>
                      _onPanStart(d, controller, state, effScale),
                  onPanEnd: (_) => _endDrag(controller),
                  onPanCancel: () => _endDrag(controller),
                  onPanUpdate: (d) =>
                      _onPanUpdate(d, controller, state, doc, effScale),
                  child: CustomPaint(
                    size: Size(artW, artH),
                    painter: CanvasPainter(
                      document: doc,
                      selectedLayerIds: state.selectedLayerIds,
                      scale: effScale,
                      offset: Offset.zero,
                      imageCache: _imageCache,
                      guides: _guides,
                      marquee: _marquee,
                      editingLayerId: _editingLayerId,
                    ),
                  ),
                ),
              ),
              // Inline text editor, positioned over the layer being edited.
              if (editing != null)
                Positioned(
                  left: editing.x * effScale,
                  top: editing.y * effScale,
                  width: editing.width * effScale,
                  height: editing.height * effScale,
                  child: _InlineTextField(
                    controller: _editController,
                    style: TextStyle(
                      fontSize: editing.fontSize * effScale,
                      color: editing.color,
                      fontFamily: editing.fontFamily,
                      fontWeight:
                          editing.bold ? FontWeight.w700 : FontWeight.w400,
                      fontStyle:
                          editing.italic ? FontStyle.italic : FontStyle.normal,
                      height: editing.lineHeight,
                      letterSpacing: editing.letterSpacing * effScale,
                    ),
                    textAlign: editing.align,
                    onCommit: () => _commitEdit(controller),
                  ),
                ),
            ],
          ),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    // Fill the viewport so a small artboard centres; overflow
                    // (a zoomed-in artboard) becomes scrollable instead.
                    constraints: BoxConstraints(minWidth: vw, minHeight: vh),
                    child: Center(child: content),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _ZoomBar(
                zoom: _zoom,
                onZoomIn: () => _setZoom(_zoom * 1.25),
                onZoomOut: () => _setZoom(_zoom / 1.25),
                onFit: () => _setZoom(1.0),
              ),
            ),
          ],
        );
      },
    );
  }

  CanvasLayer? _selectedLayer(CanvasEditorState state) {
    final id = state.selectedLayerId;
    if (id == null) return null;
    for (final layer in state.document.layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }
}

/// The overlay editor for inline text editing — a borderless, autofocused
/// field styled to match the layer, committing on blur or Cmd/Ctrl+Enter.
class _InlineTextField extends StatefulWidget {
  const _InlineTextField({
    required this.controller,
    required this.style,
    required this.textAlign,
    required this.onCommit,
  });

  final TextEditingController controller;
  final TextStyle style;
  final TextAlign textAlign;
  final VoidCallback onCommit;

  @override
  State<_InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<_InlineTextField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent, width: 1),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: null,
        expands: true,
        cursorColor: Colors.blueAccent,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        // Commit when focus leaves (click elsewhere) — the standard
        // edit-in-place gesture.
        onTapOutside: (_) => widget.onCommit(),
        onEditingComplete: widget.onCommit,
      ),
    );
  }
}

/// Floating zoom control: out / percent / in / fit-to-screen.
class _ZoomBar extends StatelessWidget {
  const _ZoomBar({
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final double zoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove, size: 18),
              onPressed: onZoomOut,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${(zoom * 100).round()}%',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium,
              ),
            ),
            IconButton(
              tooltip: 'Zoom in',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 18),
              onPressed: onZoomIn,
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Fit to screen',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.fit_screen_outlined, size: 18),
              onPressed: onFit,
            ),
          ],
        ),
      ),
    );
  }
}
