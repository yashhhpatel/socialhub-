import 'package:flutter/material.dart';

/// Single source of truth for responsive breakpoints, per docs/architecture
/// — Flutter Web Application Architecture, §6: "every responsive decision
/// in the app reads from this, so breakpoint values are changed in exactly
/// one place if they ever need adjusting."
class Breakpoints {
  const Breakpoints._();

  static const double tablet = 768;
  static const double desktop = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tablet;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tablet && width < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}
