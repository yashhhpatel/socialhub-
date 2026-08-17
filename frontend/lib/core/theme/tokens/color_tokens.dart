import 'package:flutter/material.dart';

/// Color tokens are the *only* place a color value should be written literally.
/// Widgets and screens should reference `Theme.of(context).colorScheme` (built
/// from these tokens in light_theme.dart / dark_theme.dart), never a raw
/// Color(...) value. See docs/architecture — Flutter Web Application
/// Architecture, §5 (Theme).
///
/// Palette: a light-purple + white premium SaaS look — soft lavender
/// gradients, white surfaces, dark-purple text, subtle borders. Violet
/// (#8B5CF6) is the single brand accent; everything else is a tint of it
/// or a warm neutral so the whole product reads as one design.
class ColorTokens {
  const ColorTokens._();

  // Brand — violet
  static const Color brandPrimary = Color(0xFF8B5CF6); // primary
  static const Color brandPrimaryHover = Color(0xFF7C4DF0);
  static const Color brandPrimaryDark = Color(0xFFA78BFA); // primary in dark mode

  // Lavender tints (light mode surfaces & containers)
  static const Color lavender = Color(0xFFEDE9FE); // primary container
  static const Color lavenderLight = Color(0xFFF5F3FF); // app background
  static const Color lavenderBorder = Color(0xFFE4DEF7); // subtle borders

  // Neutral scale (light mode)
  static const Color white = Color(0xFFFFFFFF);
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF5F3FF); // light lavender ground
  static const Color neutral100 = Color(0xFFF2EFFC);
  static const Color neutral300 = Color(0xFFE4DEF7);
  static const Color neutral600 = Color(0xFF6E6A85); // muted text
  static const Color neutral900 = Color(0xFF27233A); // primary text

  // Neutral scale (dark mode) — purple-tinted charcoal, not pure black
  static const Color neutralDark0 = Color(0xFF15121F);
  static const Color neutralDark50 = Color(0xFF1A1626); // dark app background
  static const Color neutralDark100 = Color(0xFF241F33); // dark surface
  static const Color neutralDark300 = Color(0xFF352E4D); // dark border
  static const Color neutralDark600 = Color(0xFFB0A8C9); // dark muted text
  static const Color neutralDark900 = Color(0xFFEDE9FE); // dark primary text

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);

  // Decorative gradient stops (soft abstract shapes / hero backgrounds)
  static const Color gradientStart = Color(0xFFF5F3FF);
  static const Color gradientMid = Color(0xFFEDE9FE);
  static const Color gradientEnd = Color(0xFFFFFFFF);
  static const Color blobViolet = Color(0xFF8B5CF6);
  static const Color blobPink = Color(0xFFC4B5FD);
}
