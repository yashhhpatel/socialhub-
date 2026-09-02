import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens/spacing_tokens.dart';
import '../canvas/models/canvas_document.dart';
import '../canvas/models/canvas_layer.dart';
import '../canvas/state/canvas_controller.dart';

const _colorSwatches = <Color>[
  Color(0xFF111827), // near-black
  Color(0xFFFFFFFF),
  Color(0xFF6B7280),
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFF6C5CE7),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
];

/// Recently applied colours, so a custom colour picked once is one tap away
/// for the rest of the session. Session-only (a StateProvider), capped at 8.
final _recentColorsProvider = StateProvider<List<Color>>((ref) => const []);

/// Font families offered for text layers. Null = the app default. Only
/// families that actually render on web CanvasKit are listed.
const _fontFamilies = <({String label, String? family})>[
  (label: 'Default', family: null),
  (label: 'Lato', family: 'Lato'),
  (label: 'Roboto', family: 'Roboto'),
];

/// Shows editable properties for the selected layer — position, size,
/// rotation, opacity, alignment, and type-specific controls (text format,
/// colour, shape border/corners, video trim). When nothing is selected it
/// shows the canvas's own properties (background colour).
class PropertyPanel extends ConsumerWidget {
  const PropertyPanel({super.key, required this.document});

  final CanvasDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = canvasControllerProvider(document);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final multi = state.selectedLayerIds.length > 1;
    final selectedLayer =
        multi ? null : _findLayerById(state.document.layers, state.selectedLayerId);

    final Widget body;
    if (multi) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: _MultiSelectProperties(
          count: state.selectedLayerIds.length,
          controller: controller,
        ),
      );
    } else if (selectedLayer == null) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: _CanvasProperties(
          document: state.document,
          controller: controller,
        ),
      );
    } else {
      body = SingleChildScrollView(
        // Keyed on layer id so switching the selection gives every field a
        // fresh initial value instead of carrying over stale text.
        key: ValueKey(selectedLayer.id),
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: _PropertyFields(layer: selectedLayer, controller: controller),
      );
    }

    return Container(
      width: 260,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(SpacingTokens.md),
            child: Text(
              multi
                  ? '${state.selectedLayerIds.length} selected'
                  : selectedLayer == null
                      ? 'Canvas'
                      : 'Properties',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  CanvasLayer? _findLayerById(List<CanvasLayer> layers, String? id) {
    if (id == null) return null;
    for (final layer in layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }
}

/// Canvas-level properties, shown when no layer is selected: the artboard's
/// background colour and its current size.
class _CanvasProperties extends StatelessWidget {
  const _CanvasProperties({required this.document, required this.controller});

  final CanvasDocument document;
  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Background'),
        _ColorControl(
          selectedColor: document.backgroundColor,
          onColorSelected: controller.setBackgroundColor,
        ),
        const SizedBox(height: SpacingTokens.lg),
        const _SectionLabel('Artboard size'),
        Text(
          '${document.width.round()} × ${document.height.round()}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: SpacingTokens.xs),
        Text(
          'Use "Resize" in the toolbar to switch platform sizes.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.lg),
        Text(
          'Select a layer to edit it, or add one from the toolbar.',
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
      ],
    );
  }
}

/// Shown when several layers are selected: align them to each other, space
/// them evenly, or match their sizes.
class _MultiSelectProperties extends StatelessWidget {
  const _MultiSelectProperties({required this.count, required this.controller});

  final int count;
  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count layers selected',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: SpacingTokens.lg),
        const _SectionLabel('Align to each other'),
        Wrap(
          children: [
            _alignBtn(Icons.align_horizontal_left, 'Left', LayerAlignment.left),
            _alignBtn(Icons.align_horizontal_center, 'Center', LayerAlignment.hCenter),
            _alignBtn(Icons.align_horizontal_right, 'Right', LayerAlignment.right),
            _alignBtn(Icons.align_vertical_top, 'Top', LayerAlignment.top),
            _alignBtn(Icons.align_vertical_center, 'Middle', LayerAlignment.vCenter),
            _alignBtn(Icons.align_vertical_bottom, 'Bottom', LayerAlignment.bottom),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Distribute (3+)'),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  controller.distributeSelected(DistributeAxis.horizontal),
              icon: const Icon(Icons.horizontal_distribute, size: 18),
              label: const Text('Horizontal'),
            ),
            const SizedBox(width: SpacingTokens.sm),
            OutlinedButton.icon(
              onPressed: () =>
                  controller.distributeSelected(DistributeAxis.vertical),
              icon: const Icon(Icons.vertical_distribute, size: 18),
              label: const Text('Vertical'),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Match size'),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => controller.matchSelectedSize(width: true),
              child: const Text('Width'),
            ),
            const SizedBox(width: SpacingTokens.sm),
            OutlinedButton(
              onPressed: () => controller.matchSelectedSize(width: false),
              child: const Text('Height'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _alignBtn(IconData icon, String tip, LayerAlignment a) => IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 18),
        onPressed: () => controller.alignSelectedToSelection(a),
      );
}

class _PropertyFields extends StatelessWidget {
  const _PropertyFields({required this.layer, required this.controller});

  final CanvasLayer layer;
  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    // Local copy so `is` checks promote it (a widget field never promotes),
    // which lets the video-only section read trim fields without a cast.
    final layer = this.layer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Position'),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                label: 'X',
                value: layer.x,
                onChanged: (v) => controller.updateSelectedLayerGeometry(x: v),
              ),
            ),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: _NumberField(
                label: 'Y',
                value: layer.y,
                onChanged: (v) => controller.updateSelectedLayerGeometry(y: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Size'),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                label: 'Width',
                value: layer.width,
                onChanged: (v) => controller.updateSelectedLayerGeometry(width: v),
              ),
            ),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: _NumberField(
                label: 'Height',
                value: layer.height,
                onChanged: (v) => controller.updateSelectedLayerGeometry(height: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Arrange on canvas'),
        _ArrangeRow(controller: controller),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Flip'),
        Row(
          children: [
            _ToggleIcon(
              icon: Icons.flip,
              tooltip: 'Flip horizontal',
              active: layer.flipH,
              onPressed: () => controller.flipSelected(horizontal: true),
            ),
            const SizedBox(width: SpacingTokens.xs),
            _ToggleIcon(
              icon: Icons.flip,
              quarterTurns: 1,
              tooltip: 'Flip vertical',
              active: layer.flipV,
              onPressed: () => controller.flipSelected(horizontal: false),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Rotation'),
        _NumberField(
          label: 'Degrees',
          value: layer.rotationDegrees,
          onChanged: (v) => controller.updateSelectedLayerGeometry(rotationDegrees: v),
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Opacity'),
        Slider(
          value: layer.opacity.clamp(0.0, 1.0),
          // Bracketed like the canvas drag: dragging the slider streams
          // dozens of updates that must collapse into one undo step.
          onChangeStart: (_) => controller.beginInteraction(),
          onChanged: (v) => controller.updateSelectedLayerGeometry(opacity: v),
          onChangeEnd: (_) => controller.endInteraction(),
        ),
        if (layer is TextCanvasLayer) ...[
          const SizedBox(height: SpacingTokens.md),
          const _SectionLabel('Text'),
          _LayerTextField(
            value: layer.text,
            onChanged: controller.updateSelectedLayerText,
          ),
          const SizedBox(height: SpacingTokens.md),
          _TextFormatControls(layer: layer, controller: controller),
        ],
        if (layer is ShapeCanvasLayer || layer is TextCanvasLayer) ...[
          const SizedBox(height: SpacingTokens.md),
          const _SectionLabel('Color'),
          _ColorControl(
            selectedColor: switch (layer) {
              ShapeCanvasLayer(:final fillColor) => fillColor,
              TextCanvasLayer(:final color) => color,
              ImageCanvasLayer() => null,
              VideoCanvasLayer() => null,
            },
            onColorSelected: controller.updateSelectedLayerColor,
          ),
        ],
        if (layer is ShapeCanvasLayer) ...[
          const SizedBox(height: SpacingTokens.md),
          _ShapeStyleControls(layer: layer, controller: controller),
        ],
        if (layer is VideoCanvasLayer) ...[
          const SizedBox(height: SpacingTokens.md),
          const _SectionLabel('Trim (seconds)'),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Start',
                  value: layer.trimStartSeconds,
                  onChanged: (v) =>
                      controller.updateSelectedVideoTrim(start: v < 0 ? 0 : v),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Expanded(
                child: _NumberField(
                  label: 'End',
                  // 0 renders when the end is open ("to the end"); the
                  // backend treats <= start as no trim, so it's a safe
                  // sentinel here.
                  value: layer.trimEndSeconds ?? 0,
                  onChanged: (v) =>
                      controller.updateSelectedVideoTrim(end: v <= 0 ? null : v),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Align-to-artboard controls (left/center/right, top/middle/bottom).
class _ArrangeRow extends StatelessWidget {
  const _ArrangeRow({required this.controller});

  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, LayerAlignment a) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 18),
          onPressed: () => controller.alignSelectedToArtboard(a),
        );
    return Wrap(
      spacing: 0,
      children: [
        btn(Icons.align_horizontal_left, 'Left', LayerAlignment.left),
        btn(Icons.align_horizontal_center, 'Center', LayerAlignment.hCenter),
        btn(Icons.align_horizontal_right, 'Right', LayerAlignment.right),
        btn(Icons.align_vertical_top, 'Top', LayerAlignment.top),
        btn(Icons.align_vertical_center, 'Middle', LayerAlignment.vCenter),
        btn(Icons.align_vertical_bottom, 'Bottom', LayerAlignment.bottom),
      ],
    );
  }
}

/// Bold / italic / alignment / line-height / font-family for a text layer.
class _TextFormatControls extends StatelessWidget {
  const _TextFormatControls({required this.layer, required this.controller});

  final TextCanvasLayer layer;
  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Font size'),
        _NumberField(
          label: 'Size',
          value: layer.fontSize,
          onChanged: controller.updateSelectedTextFontSize,
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Font'),
        DropdownButton<String?>(
          isExpanded: true,
          value: _fontFamilies.any((f) => f.family == layer.fontFamily)
              ? layer.fontFamily
              : null,
          items: [
            for (final f in _fontFamilies)
              DropdownMenuItem<String?>(value: f.family, child: Text(f.label)),
          ],
          onChanged: (family) =>
              controller.updateSelectedTextFontFamily(family),
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Style'),
        Row(
          children: [
            _ToggleIcon(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              active: layer.bold,
              onPressed: () =>
                  controller.updateSelectedTextFormat(bold: !layer.bold),
            ),
            const SizedBox(width: SpacingTokens.xs),
            _ToggleIcon(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              active: layer.italic,
              onPressed: () =>
                  controller.updateSelectedTextFormat(italic: !layer.italic),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Alignment'),
        Row(
          children: [
            _ToggleIcon(
              icon: Icons.format_align_left,
              tooltip: 'Align left',
              active: layer.align == TextAlign.left,
              onPressed: () =>
                  controller.updateSelectedTextFormat(align: TextAlign.left),
            ),
            const SizedBox(width: SpacingTokens.xs),
            _ToggleIcon(
              icon: Icons.format_align_center,
              tooltip: 'Align center',
              active: layer.align == TextAlign.center,
              onPressed: () =>
                  controller.updateSelectedTextFormat(align: TextAlign.center),
            ),
            const SizedBox(width: SpacingTokens.xs),
            _ToggleIcon(
              icon: Icons.format_align_right,
              tooltip: 'Align right',
              active: layer.align == TextAlign.right,
              onPressed: () =>
                  controller.updateSelectedTextFormat(align: TextAlign.right),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        const _SectionLabel('Line height'),
        _NumberField(
          label: 'e.g. 1.2',
          value: layer.lineHeight,
          onChanged: (v) => controller.updateSelectedTextFormat(
            lineHeight: v <= 0 ? 1.0 : v,
          ),
        ),
      ],
    );
  }
}

/// Border colour/width and corner radius for a shape layer.
class _ShapeStyleControls extends StatelessWidget {
  const _ShapeStyleControls({required this.layer, required this.controller});

  final ShapeCanvasLayer layer;
  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Border'),
        _ColorControl(
          selectedColor: layer.strokeColor,
          onColorSelected: (c) => controller.updateSelectedShapeStyle(
            strokeColor: c,
            // Give a new border a visible default width if it had none.
            strokeWidth: layer.strokeWidth <= 0 ? 4 : null,
          ),
        ),
        const SizedBox(height: SpacingTokens.sm),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                label: 'Border width',
                value: layer.strokeWidth,
                onChanged: (v) =>
                    controller.updateSelectedShapeStyle(strokeWidth: v < 0 ? 0 : v),
              ),
            ),
            const SizedBox(width: SpacingTokens.xs),
            IconButton(
              tooltip: 'Remove border',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.format_color_reset_outlined, size: 18),
              onPressed: () =>
                  controller.updateSelectedShapeStyle(clearStroke: true, strokeWidth: 0),
            ),
          ],
        ),
        if (layer.shapeKind == ShapeKind.rectangle) ...[
          const SizedBox(height: SpacingTokens.md),
          const _SectionLabel('Corner radius'),
          _NumberField(
            label: 'Radius',
            value: layer.cornerRadius,
            onChanged: (v) =>
                controller.updateSelectedShapeStyle(cornerRadius: v < 0 ? 0 : v),
          ),
        ],
      ],
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
    this.quarterTurns = 0,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  /// Rotates the icon glyph (e.g. the mirror icon turned 90° for vertical flip).
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primary.withOpacity(0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        color: active ? scheme.primary : scheme.onSurface.withOpacity(0.7),
        icon: RotatedBox(quarterTurns: quarterTurns, child: Icon(icon, size: 18)),
        onPressed: onPressed,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
      ),
    );
  }
}

/// Colour control: preset swatches, a "recent" row, and a hex input for any
/// custom colour. Applying a colour records it in [_recentColorsProvider].
class _ColorControl extends ConsumerStatefulWidget {
  const _ColorControl({required this.selectedColor, required this.onColorSelected});

  final Color? selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  ConsumerState<_ColorControl> createState() => _ColorControlState();
}

class _ColorControlState extends ConsumerState<_ColorControl> {
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _hex = TextEditingController();
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _apply(Color color) {
    widget.onColorSelected(color);
    final recent = [...ref.read(_recentColorsProvider)]
      ..removeWhere((c) => c == color)
      ..insert(0, color);
    ref.read(_recentColorsProvider.notifier).state = recent.take(8).toList();
  }

  void _applyHex() {
    final parsed = _parseHex(_hex.text);
    if (parsed != null) {
      _apply(parsed);
      _hex.clear();
    }
  }

  static Color? _parseHex(String input) {
    var hex = input.trim().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(_recentColorsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SwatchWrap(
          colors: _colorSwatches,
          selectedColor: widget.selectedColor,
          onTapped: _apply,
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.sm),
          const _MiniLabel('Recent'),
          _SwatchWrap(
            colors: recent,
            selectedColor: widget.selectedColor,
            onTapped: _apply,
          ),
        ],
        const SizedBox(height: SpacingTokens.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hex,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixText: '#',
                  hintText: 'RRGGBB',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _applyHex(),
              ),
            ),
            const SizedBox(width: SpacingTokens.xs),
            IconButton(
              tooltip: 'Apply hex colour',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.check, size: 18),
              onPressed: _applyHex,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
        ),
      );
}

class _SwatchWrap extends StatelessWidget {
  const _SwatchWrap({
    required this.colors,
    required this.selectedColor,
    required this.onTapped,
  });

  final List<Color> colors;
  final Color? selectedColor;
  final ValueChanged<Color> onTapped;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SpacingTokens.sm,
      runSpacing: SpacingTokens.sm,
      children: [
        for (final color in colors)
          GestureDetector(
            onTap: () => onTapped(color),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == selectedColor
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.withOpacity(0.4),
                  width: color == selectedColor ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Multiline text field for editing a text layer's content from the property
/// panel. Same focus-aware resync discipline as [_NumberField]: only pulls a
/// new value from `value` when it doesn't hold focus, so an external change
/// (e.g. a double-click edit on the canvas) reflects here without stomping an
/// in-progress edit. Commits on submit and on tap-outside.
class _LayerTextField extends StatefulWidget {
  const _LayerTextField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_LayerTextField> createState() => _LayerTextFieldState();
}

class _LayerTextFieldState extends State<_LayerTextField> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _LayerTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _textController.text = widget.value;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: 4,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onSubmitted: widget.onChanged,
      onTapOutside: (_) => widget.onChanged(_textController.text),
    );
  }
}

/// Numeric text field that stays in sync with external state changes
/// (e.g. dragging the layer on the canvas updates X/Y, which this field
/// should reflect) WITHOUT stomping on an in-progress edit — only
/// resyncs its text from `value` when it doesn't currently have focus.
class _NumberField extends StatefulWidget {
  const _NumberField({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _textController.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _format(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  void _commit(String text) {
    final parsed = double.tryParse(text);
    if (parsed != null) {
      widget.onChanged(parsed);
    } else {
      // Invalid input (e.g. empty, or non-numeric) — revert rather than
      // leaving garbage in the field or propagating NaN into the layer.
      _textController.text = _format(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _textController,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onFieldSubmitted: _commit,
      onTapOutside: (_) => _commit(_textController.text),
    );
  }
}
