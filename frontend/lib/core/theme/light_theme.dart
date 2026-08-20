import 'package:flutter/material.dart';

import '../motion/motion_page_transitions.dart';
import 'tokens/color_tokens.dart';
import 'tokens/typography_tokens.dart';

/// Light ThemeData — the primary, default look of SocialHub: a light-purple
/// + white premium SaaS design. Built entirely from tokens; never a raw
/// color/font value here. See docs/architecture — Flutter Web Application
/// Architecture, §5 (Theme).
///
/// Every reusable Material component (buttons, inputs, cards, chips, dialogs,
/// menus, snackbars, tables…) is themed centrally here so the whole product
/// stays visually consistent without each screen restyling anything.
final ThemeData lightTheme = _buildLightTheme();

const _radiusSm = 10.0;
const _radiusMd = 14.0;
const _radiusLg = 18.0;

ThemeData _buildLightTheme() {
  const colorScheme = ColorScheme.light(
    primary: ColorTokens.brandPrimary,
    onPrimary: ColorTokens.white,
    primaryContainer: ColorTokens.lavender,
    onPrimaryContainer: ColorTokens.neutral900,
    secondary: ColorTokens.brandPrimary,
    onSecondary: ColorTokens.white,
    secondaryContainer: ColorTokens.lavender,
    onSecondaryContainer: ColorTokens.neutral900,
    surface: ColorTokens.white,
    onSurface: ColorTokens.neutral900,
    surfaceContainerHighest: ColorTokens.neutral100,
    surfaceContainerHigh: ColorTokens.lavenderLight,
    onSurfaceVariant: ColorTokens.neutral600,
    outline: ColorTokens.lavenderBorder,
    outlineVariant: ColorTokens.neutral300,
    error: ColorTokens.error,
    onError: ColorTokens.white,
  );

  final textTheme = _textTheme(ColorTokens.neutral900, ColorTokens.neutral600);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: TypographyTokens.fontFamily,
    scaffoldBackgroundColor: ColorTokens.lavenderLight,
    canvasColor: ColorTokens.white,
    colorScheme: colorScheme,
    textTheme: textTheme,
    // App-wide fade + 12px upward slide page transitions (motion layer).
    pageTransitionsTheme: kMotionPageTransitionsTheme,
    dividerColor: ColorTokens.lavenderBorder,
    dividerTheme: const DividerThemeData(
      color: ColorTokens.lavenderBorder,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ColorTokens.white,
      foregroundColor: ColorTokens.neutral900,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: ColorTokens.lavenderBorder)),
    ),
    cardTheme: CardTheme(
      color: ColorTokens.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: ColorTokens.brandPrimary.withOpacity(0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLg),
        side: const BorderSide(color: ColorTokens.lavenderBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _primaryButtonStyle()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButtonStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(ColorTokens.brandPrimary),
        backgroundColor: const WidgetStatePropertyAll(ColorTokens.white),
        overlayColor:
            WidgetStatePropertyAll(ColorTokens.lavender.withOpacity(0.6)),
        side: const WidgetStatePropertyAll(
          BorderSide(color: ColorTokens.lavenderBorder),
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
        foregroundColor: const WidgetStatePropertyAll(ColorTokens.brandPrimary),
        overlayColor:
            WidgetStatePropertyAll(ColorTokens.lavender.withOpacity(0.6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(ColorTokens.neutral600),
        overlayColor:
            WidgetStatePropertyAll(ColorTokens.lavender.withOpacity(0.6)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ColorTokens.lavender
              : ColorTokens.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ColorTokens.brandPrimary
              : ColorTokens.neutral600,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: ColorTokens.lavenderBorder),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusSm)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColorTokens.white,
      hintStyle: const TextStyle(color: ColorTokens.neutral600),
      labelStyle: const TextStyle(color: ColorTokens.neutral600),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _inputBorder(ColorTokens.lavenderBorder),
      enabledBorder: _inputBorder(ColorTokens.lavenderBorder),
      focusedBorder: _inputBorder(ColorTokens.brandPrimary, width: 1.6),
      errorBorder: _inputBorder(ColorTokens.error),
      focusedErrorBorder: _inputBorder(ColorTokens.error, width: 1.6),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ColorTokens.lavender,
      selectedColor: ColorTokens.brandPrimary,
      secondarySelectedColor: ColorTokens.brandPrimary,
      side: BorderSide.none,
      labelStyle: const TextStyle(
        color: ColorTokens.neutral900,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: ColorTokens.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: ColorTokens.brandPrimary.withOpacity(0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLg + 4),
      ),
      titleTextStyle: TypographyTokens.headingMedium
          .copyWith(color: ColorTokens.neutral900),
      contentTextStyle: TypographyTokens.bodyMedium
          .copyWith(color: ColorTokens.neutral900),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColorTokens.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusLg + 4)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: ColorTokens.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: ColorTokens.brandPrimary.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        side: const BorderSide(color: ColorTokens.lavenderBorder),
      ),
      textStyle: TypographyTokens.bodyMedium
          .copyWith(color: ColorTokens.neutral900),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(ColorTokens.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            side: const BorderSide(color: ColorTokens.lavenderBorder),
          ),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColorTokens.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _inputBorder(ColorTokens.lavenderBorder),
        enabledBorder: _inputBorder(ColorTokens.lavenderBorder),
        focusedBorder: _inputBorder(ColorTokens.brandPrimary, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColorTokens.neutral900,
      contentTextStyle: const TextStyle(color: ColorTokens.white),
      actionTextColor: ColorTokens.brandPrimaryDark,
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: ColorTokens.neutral600,
      textColor: ColorTokens.neutral900,
      selectedColor: ColorTokens.brandPrimary,
      selectedTileColor: ColorTokens.lavenderLight,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ColorTokens.white
            : ColorTokens.neutral600,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ColorTokens.brandPrimary
            : ColorTokens.neutral300,
      ),
      trackOutlineColor:
          const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ColorTokens.brandPrimary
            : Colors.transparent,
      ),
      side: const BorderSide(color: ColorTokens.neutral300, width: 1.5),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: ColorTokens.brandPrimary,
      unselectedLabelColor: ColorTokens.neutral600,
      indicatorColor: ColorTokens.brandPrimary,
      dividerColor: ColorTokens.lavenderBorder,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: ColorTokens.neutral900,
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
      textStyle: const TextStyle(color: ColorTokens.white, fontSize: 12),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColorTokens.brandPrimary,
      circularTrackColor: ColorTokens.lavender,
      linearTrackColor: ColorTokens.lavender,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: ColorTokens.white,
      surfaceTintColor: Colors.transparent,
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor:
          WidgetStatePropertyAll(ColorTokens.lavenderLight),
      headingTextStyle: TextStyle(
        color: ColorTokens.neutral900,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      dataTextStyle: TextStyle(color: ColorTokens.neutral900, fontSize: 14),
      dividerThickness: 1,
    ),
  );
}

ButtonStyle _primaryButtonStyle() => ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? ColorTokens.brandPrimaryHover
            : ColorTokens.brandPrimary,
      ),
      foregroundColor: const WidgetStatePropertyAll(ColorTokens.white),
      overlayColor: const WidgetStatePropertyAll(Colors.white24),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: WidgetStatePropertyAll(
        ColorTokens.brandPrimary.withOpacity(0.35),
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
    );

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );

TextTheme _textTheme(Color body, Color muted) => const TextTheme(
      headlineLarge: TypographyTokens.headingLarge,
      headlineMedium: TypographyTokens.headingMedium,
      titleLarge: TypographyTokens.titleLarge,
      titleMedium: TypographyTokens.titleMedium,
      bodyLarge: TypographyTokens.bodyLarge,
      bodyMedium: TypographyTokens.bodyMedium,
      labelSmall: TypographyTokens.labelSmall,
    ).apply(bodyColor: body, displayColor: body);
