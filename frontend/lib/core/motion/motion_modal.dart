import 'package:flutter/material.dart';

import 'motion.dart';

/// [showDialog] with the app's modal entrance: scale-in from
/// [Motion.scaleFrom] + fade, [Motion.entrance], over [Motion.base]. Use this
/// in place of a bare `showDialog` so every modal (composer, confirmations,
/// enrolment flows) enters the same way. Honours reduced motion (instant).
///
/// A drop-in wrapper — [builder] returns the same dialog widget you'd pass to
/// `showDialog`, so switching a call site over is a one-line change with no
/// behavioural difference.
Future<T?> showMotionModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel:
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: Motion.duration(context, Motion.base),
    pageBuilder: (context, _, __) => Builder(builder: builder),
    transitionBuilder: (context, animation, _, child) {
      if (Motion.reduceMotion(context)) return child;
      final curved =
          CurvedAnimation(parent: animation, curve: Motion.entrance);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: Motion.scaleFrom, end: 1.0)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}
