import 'package:flutter/material.dart';

import '../../brand_kit/domain/entities/brand_kit.dart';
import 'models/canvas_document.dart';
import 'models/canvas_layer.dart';

/// Applies a brand kit across a whole design (Milestone 9.3), returning a
/// new document — pure, so it's trivially testable and the caller decides
/// when to commit it (the editor pushes it through
/// CanvasController.replaceDocument as one undoable edit).
///
/// The rules are deliberately simple and predictable, so a user can look at
/// the result and understand what "apply" did:
///   - text layers take the primary brand font and the primary colour;
///   - shape layers take the accent colour (the 2nd colour, or the primary
///     if only one is defined);
///   - image layers are left untouched (a brand kit restyles type and
///     fills, not uploaded imagery).
/// A field the kit doesn't define is left as-is rather than blanked — an
/// empty kit is a no-op, not a wipe.
CanvasDocument applyBrandKit(CanvasDocument document, BrandKit kit) {
  if (kit.isEmpty) return document;

  final primary = _parseHexColor(kit.primaryColor);
  final accent = _parseHexColor(kit.accentColor);
  final font = kit.primaryFont;

  final restyled = <CanvasLayer>[
    for (final layer in document.layers)
      switch (layer) {
        TextCanvasLayer text => _applyToText(text, primary, font),
        ShapeCanvasLayer shape =>
          accent == null ? shape : shape.copyWithFillColor(accent),
        ImageCanvasLayer image => image,
      },
  ];

  return document.copyWithLayers(restyled);
}

TextCanvasLayer _applyToText(TextCanvasLayer layer, Color? color, String? font) {
  var result = layer;
  if (color != null) result = result.copyWithColor(color);
  if (font != null) result = result.copyWithFontFamily(font);
  return result;
}

/// Parses a CSS-style hex colour (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`)
/// into a Flutter ARGB [Color]. Returns null for null/malformed input so
/// the caller simply skips recolouring rather than throwing mid-transform.
Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);

  // Expand shorthand (#RGB / #RGBA) to full form.
  if (value.length == 3 || value.length == 4) {
    value = value.split('').map((c) => '$c$c').join();
  }

  if (value.length == 6) {
    value = 'FF$value'; // opaque; Flutter wants AARRGGBB
  } else if (value.length == 8) {
    // CSS is RRGGBBAA; Flutter is AARRGGBB — move the alpha to the front.
    value = value.substring(6, 8) + value.substring(0, 6);
  } else {
    return null;
  }

  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}
