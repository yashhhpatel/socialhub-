import 'package:flutter/material.dart';

import '../motion/motion_page_transitions.dart';
import 'tokens/color_tokens.dart';
import 'tokens/typography_tokens.dart';

/// Dark ThemeData — a purple-tinted dark variant that mirrors the light
/// design's shapes, radii and component styling so switching themes never
/// changes the product's personality, only its brightness. Light is the
/// default (see theme_mode_controller.dart); this is the opt-in mode.
final ThemeData darkTheme = _buildDarkTheme();

const _radiusSm = 10.0;
const _radiusMd = 14.0;
const _radiusLg = 18.0;

ThemeData _buildDarkTheme() {
  const colorScheme = ColorScheme.dark(
    primary: ColorTokens.brandPrimaryDark,
    onPrimary: ColorTokens.neutralDark0,
    primaryContainer: ColorTokens.neutralDark300,
    onPrimaryContainer: ColorTokens.neutralDark900,
    secondary: ColorTokens.brandPrimaryDark,
    onSecondary: ColorTokens.neutralDark0,
    secondaryContainer: ColorTokens.neutralDark300,
    onSecondaryContainer: ColorTokens.neutralDark900,
    surface: ColorTokens.neutralDark100,
    onSurface: ColorTokens.neutralDark900,
    surfaceContainerHighest: ColorTokens.neutralDark300,
    surfaceContainerHigh: ColorTokens.neutralDark50,
    onSurfaceVariant: ColorTokens.neutralDark600,
    outline: ColorTokens.neutralDark300,
    outlineVariant: ColorTokens.neutralDark300,
    error: ColorTokens.error,
    onError: ColorTokens.white,
  );

  final textTheme = const TextTheme(
    headlineLarge: TypographyTokens.headingLarge,
    headlineMedium: TypographyTokens.headingMedium,
    titleLarge: TypographyTokens.titleLarge,
    titleMedium: TypographyTokens.titleMedium,
    bodyLarge: TypographyTokens.bodyLarge,
    bodyMedium: TypographyTokens.bodyMedium,
    labelSmall: TypographyTokens.labelSmall,
  ).apply(
    bodyColor: ColorTokens.neutralDark900,
    displayColor: ColorTokens.neutralDark900,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: TypographyTokens.fontFamily,
    scaffoldBackgroundColor: ColorTokens.neutralDark50,
    canvasColor: ColorTokens.neutralDark100,
    colorScheme: colorScheme,
    textTheme: textTheme,
    // App-wide fade + 12px upward slide page transitions (motion layer).
    pageTransitionsTheme: kMotionPageTransitionsTheme,
    dividerColor: ColorTokens.neutralDark300,
    dividerTheme: const DividerThemeData(
      color: ColorTokens.neutralDark300,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ColorTokens.neutralDark100,
      foregroundColor: ColorTokens.neutralDark900,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: ColorTokens.neutralDark300)),
    ),
    cardTheme: CardTheme(
      color: ColorTokens.neutralDark100,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLg),
        side: const BorderSide(color: ColorTokens.neutralDark300),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor:
            const WidgetStatePropertyAll(ColorTokens.brandPrimaryDark),
        side: const WidgetStatePropertyAll(
          BorderSide(color: ColorTokens.neutralDark300),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor:
            const WidgetStatePropertyAll(ColorTokens.brandPrimaryDark),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColorTokens.neutralDark50,
      hintStyle: const TextStyle(color: ColorTokens.neutralDark600),
      labelStyle: const TextStyle(color: ColorTokens.neutralDark600),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _inputBorder(ColorTokens.neutralDark300),
      enabledBorder: _inputBorder(ColorTokens.neutralDark300),
      focusedBorder: _inputBorder(ColorTokens.brandPrimaryDark, width: 1.6),
      errorBorder: _inputBorder(ColorTokens.error),
      focusedErrorBorder: _inputBorder(ColorTokens.error, width: 1.6),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ColorTokens.neutralDark300,
      side: BorderSide.none,
      labelStyle: const TextStyle(
        color: ColorTokens.neutralDark900,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: ColorTokens.neutralDark100,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLg + 4),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: ColorTokens.neutralDark100,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        side: const BorderSide(color: ColorTokens.neutralDark300),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColorTokens.neutralDark300,
      contentTextStyle: const TextStyle(color: ColorTokens.neutralDark900),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ColorTokens.white
            : ColorTokens.neutralDark600,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ColorTokens.brandPrimaryDark
            : ColorTokens.neutralDark300,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: ColorTokens.brandPrimaryDark,
      unselectedLabelColor: ColorTokens.neutralDark600,
      indicatorColor: ColorTokens.brandPrimaryDark,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: ColorTokens.neutralDark0,
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
      textStyle: const TextStyle(color: ColorTokens.neutralDark900, fontSize: 12),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColorTokens.brandPrimaryDark,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: ColorTokens.neutralDark100,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

ButtonStyle _primaryButtonStyle() => ButtonStyle(
      backgroundColor:
          const WidgetStatePropertyAll(ColorTokens.brandPrimaryDark),
      foregroundColor: const WidgetStatePropertyAll(ColorTokens.neutralDark0),
      overlayColor: const WidgetStatePropertyAll(Colors.white24),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusMd)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
