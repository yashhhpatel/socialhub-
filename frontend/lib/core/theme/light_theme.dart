import 'package:flutter/material.dart';

import 'tokens/color_tokens.dart';
import 'tokens/typography_tokens.dart';

/// Light ThemeData, built entirely from tokens — never a raw color/font
/// value here. See docs/architecture — Flutter Web Application
/// Architecture, §5 (Theme).
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: ColorTokens.neutral50,
  colorScheme: const ColorScheme.light(
    primary: ColorTokens.brandPrimary,
    onPrimary: ColorTokens.neutral0,
    surface: ColorTokens.neutral0,
    onSurface: ColorTokens.neutral900,
    error: ColorTokens.error,
  ),
  textTheme: const TextTheme(
    headlineLarge: TypographyTokens.headingLarge,
    headlineMedium: TypographyTokens.headingMedium,
    bodyLarge: TypographyTokens.bodyLarge,
    bodyMedium: TypographyTokens.bodyMedium,
    labelSmall: TypographyTokens.labelSmall,
  ).apply(
    bodyColor: ColorTokens.neutral900,
    displayColor: ColorTokens.neutral900,
  ),
  dividerColor: ColorTokens.neutral300,
);
