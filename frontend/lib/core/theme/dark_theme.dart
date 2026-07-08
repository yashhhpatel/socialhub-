import 'package:flutter/material.dart';

import 'tokens/color_tokens.dart';
import 'tokens/typography_tokens.dart';

/// Dark ThemeData, built entirely from tokens — mirrors light_theme.dart.
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ColorTokens.neutralDark50,
  colorScheme: const ColorScheme.dark(
    primary: ColorTokens.brandPrimaryDark,
    onPrimary: ColorTokens.neutralDark0,
    surface: ColorTokens.neutralDark100,
    onSurface: ColorTokens.neutralDark900,
    error: ColorTokens.error,
  ),
  textTheme: const TextTheme(
    headlineLarge: TypographyTokens.headingLarge,
    headlineMedium: TypographyTokens.headingMedium,
    bodyLarge: TypographyTokens.bodyLarge,
    bodyMedium: TypographyTokens.bodyMedium,
    labelSmall: TypographyTokens.labelSmall,
  ).apply(
    bodyColor: ColorTokens.neutralDark900,
    displayColor: ColorTokens.neutralDark900,
  ),
  dividerColor: ColorTokens.neutralDark300,
);
