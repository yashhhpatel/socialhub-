import 'package:flutter/material.dart';

import 'motion.dart';

/// A non-intrusive press/hover affordance: scales its child to
/// [Motion.scaleFrom] on pointer-down and back on release ([Motion.fast]),
/// and — on web/desktop — lifts a subtle shadow on hover.
///
/// Deliberately uses [Listener] and [MouseRegion], which observe pointer
/// events without consuming them, so the child's own `InkWell`/`onTap`/button
/// still fires exactly as before. This adds animation only — it never becomes
/// the tap handler, so it can wrap existing buttons and cards without changing
/// any behaviour. Under reduced motion it renders the child untouched.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.pressedScale = Motion.scaleFrom,
    this.hoverElevation = false,
    this.borderRadius,
  });

  final Widget child;

  /// Scale applied while pressed (grows back to 1.0 on release).
  final double pressedScale;

  /// When true, a soft shadow fades in on hover — for card-like surfaces.
  final bool hoverElevation;

  /// Corner radius for the hover shadow, so it matches the wrapped surface.
  final BorderRadius? borderRadius;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduceMotion(context)) return widget.child;

    Widget content = widget.child;

    if (widget.hoverElevation) {
      content = AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.stateChange,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: content,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1.0,
          duration: Motion.fast,
          curve: Motion.stateChange,
          child: content,
        ),
      ),
    );
  }
}
