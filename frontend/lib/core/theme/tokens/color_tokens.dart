import 'package:flutter/material.dart';

/// Color tokens are the *only* place a color value should be written literally.
/// Widgets and screens should reference `Theme.of(context).colorScheme` (built
/// from these tokens in light_theme.dart / dark_theme.dart), never a raw
/// Color(...) value. See docs/architecture — Flutter Web Application
/// Architecture, §5 (Theme).
class ColorTokens {
  const ColorTokens._();

  // Brand
  static const Color brandPrimary = Color(0xFF3B82F6);
  static const Color brandPrimaryDark = Color(0xFF60A5FA);

  // Neutral scale (light mode)
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral900 = Color(0xFF111827);

  // Neutral scale (dark mode)
  static const Color neutralDark0 = Color(0xFF0B0F19);
  static const Color neutralDark50 = Color(0xFF111827);
  static const Color neutralDark100 = Color(0xFF1F2937);
  static const Color neutralDark300 = Color(0xFF374151);
  static const Color neutralDark600 = Color(0xFF9CA3AF);
  static const Color neutralDark900 = Color(0xFFF9FAFB);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
}
