import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Midnight Studio ThemeData — the single dark theme for the whole app, built
/// entirely from [AppColors].
///
/// Design rules baked in here:
/// - Elevation 0 everywhere; surfaces are separated by 1px [AppColors.border],
///   never by shadows.
/// - Card radius 12; button and input radius 8.
/// - Lato type scale: headings Bold 700, section titles SemiBold 600, body
///   Regular 400, buttons/nav/labels Medium 500. Lato ships only static
///   weights, so 500/600 resolve to the nearest bundled weight (400/700).
///
/// Flutter 3.22 note: this SDK's ThemeData takes `CardTheme` / `DialogTheme` /
/// `TabBarTheme` (not the `*ThemeData` variants introduced in later SDKs).
final ThemeData midnightStudioTheme = _build();

const String _fontFamily = 'Lato';
const double _cardRadius = 12;
const double _controlRadius = 8;

ThemeData _build() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.textPrimary,
    primaryContainer: AppColors.surfaceRaised,
    onPrimaryContainer: AppColors.textPrimary,
    secondary: AppColors.accent,
    onSecondary: AppColors.textPrimary,
    secondaryContainer: AppColors.surfaceRaised,
    onSecondaryContainer: AppColors.textPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    // Raised surfaces (hover, dropdowns, skeletons) read off this token.
    surfaceContainerHighest: AppColors.surfaceRaised,
    surfaceContainerHigh: AppColors.surfaceRaised,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.error,
    onError: AppColors.textPrimary,
  );

  final textTheme = _textTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.surface,
    colorScheme: colorScheme,
    textTheme: textTheme,
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    cardTheme: CardTheme(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        overlayColor: const WidgetStatePropertyAll(AppColors.surfaceRaised),
        elevation: const WidgetStatePropertyAll(0),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_controlRadius),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.accent),
        overlayColor: const WidgetStatePropertyAll(AppColors.surfaceRaised),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_controlRadius),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(AppColors.textMuted),
        overlayColor: WidgetStatePropertyAll(AppColors.surfaceRaised),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.surfaceRaised
              : AppColors.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textMuted,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_controlRadius),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _inputBorder(AppColors.border),
      enabledBorder: _inputBorder(AppColors.border),
      focusedBorder: _inputBorder(AppColors.accentHover, width: 1.4),
      errorBorder: _inputBorder(AppColors.error),
      focusedErrorBorder: _inputBorder(AppColors.error, width: 1.4),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceRaised,
      selectedColor: AppColors.accent,
      secondarySelectedColor: AppColors.accent,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle:
          textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_cardRadius)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surfaceRaised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_controlRadius),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.accentHover, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      actionTextColor: AppColors.accentHover,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textMuted,
      textColor: AppColors.textPrimary,
      selectedColor: AppColors.accent,
      selectedTileColor: AppColors.surfaceRaised,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.textPrimary
            : AppColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.surfaceRaised,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(AppColors.border),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(AppColors.textPrimary),
      side: const BorderSide(color: AppColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.accent,
      dividerColor: AppColors.border,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(_controlRadius),
      ),
      textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      circularTrackColor: AppColors.surfaceRaised,
      linearTrackColor: AppColors.surfaceRaised,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(AppColors.surfaceRaised),
      headingTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      dataTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      dividerThickness: 1,
    ),
  );
}

/// One primary-action style: filled accent, elevation 0, radius 8. Hover lifts
/// to [AppColors.accentHover] (no shadow, no glow).
ButtonStyle _primaryButtonStyle() => ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? AppColors.accentHover
            : AppColors.accent,
      ),
      foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    );

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(_controlRadius),
      borderSide: BorderSide(color: color, width: width),
    );

/// Lato type scale. Weights follow the product spec:
/// headings Bold 700, section titles SemiBold 600, body Regular 400,
/// buttons/nav/labels Medium 500.
TextTheme _textTheme() => const TextTheme(
      displaySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      headlineLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
