import 'package:flutter/material.dart';

import 'motion.dart';

/// A shimmering placeholder block, sized like the content it stands in for.
///
/// The shimmer is a gradient sweep driven by a repeating [AnimationController]
/// (no package needed). Colours come from the theme so it reads correctly in
/// light and dark. Under reduced motion the sweep stops and it shows as a
/// still, muted block — still a placeholder, just not moving. The controller
/// is always disposed.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  /// Convenience for a circular avatar-shaped skeleton.
  factory Skeleton.circle(double size, {Key? key}) => Skeleton(
        key: key,
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
      );

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only sweep when motion is allowed; otherwise leave it static.
    if (!Motion.reduceMotion(context) && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      scheme.onSurface.withOpacity(0.06),
      base,
    );
    final radius = widget.borderRadius ?? BorderRadius.circular(8);

    if (Motion.reduceMotion(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Sweep a bright band left→right across the block.
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t) + 1, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Cross-fades between a loading placeholder and the real content: while
/// [loading], shows [skeleton]; once data arrives, the real [child] fades in
/// (and the skeleton fades out) over [Motion.base]. Honours reduced motion via
/// [Motion.duration].
///
/// A thin wrapper over [AnimatedSwitcher] so screens get a consistent
/// load→content transition instead of a hard swap from a spinner.
class SkeletonSwitcher extends StatelessWidget {
  const SkeletonSwitcher({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.duration(context, Motion.base),
      switchInCurve: Motion.entrance,
      switchOutCurve: Motion.exit,
      child: loading
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
