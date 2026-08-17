import 'package:flutter/material.dart';

/// An org's white-label branding (GET /organizations/white-label).
class WhiteLabel {
  const WhiteLabel({this.logoUrl, this.primaryColorHex});

  final String? logoUrl;
  final String? primaryColorHex;

  bool get isEmpty => logoUrl == null && primaryColorHex == null;

  /// The primary colour parsed to a Flutter [Color], or null if unset/invalid.
  Color? get primaryColor => parseHexColor(primaryColorHex);

  factory WhiteLabel.fromJson(Map<String, dynamic> json) => WhiteLabel(
        logoUrl: json['logoUrl'] as String?,
        primaryColorHex: json['primaryColor'] as String?,
      );
}

/// Parses a CSS-style hex colour (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`)
/// into an ARGB [Color]; null on null/malformed input. Shared with the
/// white-label screen's live preview.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 3 || value.length == 4) {
    value = value.split('').map((c) => '$c$c').join();
  }
  if (value.length == 6) {
    value = 'FF$value';
  } else if (value.length == 8) {
    // CSS is RRGGBBAA; Flutter is AARRGGBB — move alpha to the front.
    value = value.substring(6, 8) + value.substring(0, 6);
  } else {
    return null;
  }
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}
