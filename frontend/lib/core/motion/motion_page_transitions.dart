import 'package:flutter/material.dart';

import 'motion.dart';

/// App-wide page transition: a fade combined with a small (12px) upward
/// slide, using the entrance/exit curves. Wired into both themes via
/// [ThemeData.pageTransitionsTheme] (see light_theme/dark_theme), so it
/// replaces the platform-default MaterialPageRoute transition everywhere at
/// once — including every go_router navigation — without touching call sites.
///
/// Under reduced motion it returns the child unanimated.
class MotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const MotionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduceMotion(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.entrance,
      reverseCurve: Motion.exit,
    );

    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          // Starts 12px below its resting spot and rises to 0 — an exact
          // pixel offset (SlideTransition works in fractions of child size).
          offset: Offset(0, (1 - curved.value) * Motion.slideOffset),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// The [PageTransitionsTheme] applying [MotionPageTransitionsBuilder] across
/// every platform target (web included, which reports as one of the desktop
/// platforms).
const PageTransitionsTheme kMotionPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: MotionPageTransitionsBuilder(),
    TargetPlatform.iOS: MotionPageTransitionsBuilder(),
    TargetPlatform.linux: MotionPageTransitionsBuilder(),
    TargetPlatform.macOS: MotionPageTransitionsBuilder(),
    TargetPlatform.windows: MotionPageTransitionsBuilder(),
  },
);
