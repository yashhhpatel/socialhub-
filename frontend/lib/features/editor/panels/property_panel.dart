import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens/spacing_tokens.dart';
import '../canvas/models/canvas_document.dart';
import '../canvas/models/canvas_layer.dart';
import '../canvas/state/canvas_controller.dart';

const _colorSwatches = <Color>[
  Color(0xFF111827), // near-black
  Color(0xFFFFFFFF),
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
];

/// Shows editable position/size/rotation/opacity for the selected layer,
/// plus color for shape/text layers (not applicable to images — see
/// _ColorSection). Shows a neutral empty state when nothing is selected.
///
/// SCOPE NOTE: color editing is preset swatches, not a full HSV/hex
/// picker — a deliberate simplification for this milestone; a richer
/// picker is a reasonable future enhancement, not something this
/// milestone's "position, size, rotation, color" requirement demands be
/// built to that depth yet.
class PropertyPanel extends ConsumerWidget {
  const PropertyPanel({super.key, required this.document});

  final CanvasDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = canvasControllerProvider(document);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final selectedLayer = _findLayerById(state.document.layers, state.selectedLayerId);

    return Container(
      width: 260,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(SpacingTokens.md),
            child: Text('Properties', style: Theme.of(context).textTheme.headlineMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: selectedLayer == null
                ? Padding(
                    padding: const EdgeInsets.all(SpacingTokens.md),
                    child: Text(
                      'Select a layer to edit its properties.',
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  )
                : SingleChildScrollView(
                    // Keyed on layer id so switching the selection gives
                    // every field a fresh initial value instead of
                    // carrying over stale text from the previous layer.
                    key: ValueKey(selectedLayer.id),
                    padding: const EdgeInsets.all(SpacingTokens.md),
                    child: _PropertyFields(layer: selectedLayer, controller: controller),
                  ),
          ),
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

class _PropertyFields extends StatelessWidget {
  const _PropertyFields({required this.layer, required this.controller});

  final CanvasLayer layer;
  final CanvasController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Position'),
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
        _SectionLabel('Size'),
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
        _SectionLabel('Rotation'),
        _NumberField(
          label: 'Degrees',
          value: layer.rotationDegrees,
          onChanged: (v) => controller.updateSelectedLayerGeometry(rotationDegrees: v),
        ),
        const SizedBox(height: SpacingTokens.md),
        _SectionLabel('Opacity'),
        Slider(
          value: layer.opacity.clamp(0.0, 1.0),
          onChanged: (v) => controller.updateSelectedLayerGeometry(opacity: v),
        ),
        if (layer is ShapeCanvasLayer || layer is TextCanvasLayer) ...[
          const SizedBox(height: SpacingTokens.md),
          _SectionLabel('Color'),
          _ColorSwatchRow(
            selectedColor: switch (layer) {
              ShapeCanvasLayer(:final fillColor) => fillColor,
              TextCanvasLayer(:final color) => color,
              ImageCanvasLayer() => null,
            },
            onColorSelected: controller.updateSelectedLayerColor,
          ),
        ],
      ],
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

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({required this.selectedColor, required this.onColorSelected});

  final Color? selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SpacingTokens.sm,
      runSpacing: SpacingTokens.sm,
      children: [
        for (final color in _colorSwatches)
          GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              width: 28,
              height: 28,
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
