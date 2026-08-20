import 'package:flutter/widgets.dart';

/// The single source of truth for how SocialHub moves.
///
/// Every animated surface in the app pulls its duration, curve, and offset
/// from here, so motion reads as one system instead of a dozen ad-hoc
/// tweaks. Never hardcode a `Duration(milliseconds: …)` or a `Curves.…` at a
/// call site — reach for these constants (and the helper widgets in this
/// folder) instead.
///
/// Accessibility: honour the OS "reduce motion" setting. Wherever a duration
/// feeds a real animation, pass it through [Motion.duration] (or check
/// [Motion.reduceMotion]) so it collapses to [Duration.zero] and the widget
/// snaps straight to its final state — no motion, no delay — for users who
/// asked for that.
abstract final class Motion {
  const Motion._();

  // ── Durations ──────────────────────────────────────────────────────────
  // Nothing in the app should animate longer than [slow] (400ms).
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  // ── Curves ─────────────────────────────────────────────────────────────
  // Entrances decelerate in, exits accelerate out, state changes ease both
  // ends. Deliberately never elastic/bouncy.
  static const Curve entrance = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve stateChange = Curves.easeInOutCubic;

  // ── Standard offsets ───────────────────────────────────────────────────
  /// Vertical travel for a slide-in entrance, in logical pixels.
  static const double slideOffset = 12.0;

  /// Starting scale for a scale-in entrance (grows to 1.0).
  static const double scaleFrom = 0.97;

  // ── Stagger (list/feed entrances) ──────────────────────────────────────
  /// Delay added per successive item in a staggered list.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Cap on how many items stagger — beyond this they all share the last
  /// delay, so a long list never accumulates a laggy entrance.
  static const int maxStaggered = 8;

  // ── Reduced-motion helpers ─────────────────────────────────────────────
  /// Whether the user has asked the OS to minimise motion.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// [value], or [Duration.zero] under reduced motion. Lets a call site use
  /// the same code path either way — it just animates instantly when reduced
  /// motion is on.
  static Duration duration(BuildContext context, Duration value) =>
      reduceMotion(context) ? Duration.zero : value;

  /// The staggered start delay for the item at [index], clamped to
  /// [maxStaggered] and collapsed to zero under reduced motion.
  static Duration staggerDelay(BuildContext context, int index) =>
      reduceMotion(context)
          ? Duration.zero
          : stagger * index.clamp(0, maxStaggered);
}
