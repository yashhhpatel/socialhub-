import 'package:flutter/material.dart';

import 'motion.dart';

/// An [AnimatedSwitcher] preset to the app's motion vocabulary: incoming
/// content fades and scales in from [Motion.scaleFrom], outgoing fades away,
/// over [Motion.base]. Use it to swap conditional UI (empty ↔ loaded ↔ error,
/// a value that changes) instead of a hard `setState` replacement.
///
/// Give each distinct child a `key` so the switcher knows when to animate.
/// Honours reduced motion (collapses to an instant swap).
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    super.key,
    required this.child,
    this.duration,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration? duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.duration(context, duration ?? Motion.base),
      switchInCurve: Motion.entrance,
      switchOutCurve: Motion.exit,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: Motion.scaleFrom, end: 1.0)
              .animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
