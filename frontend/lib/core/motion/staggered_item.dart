import 'package:flutter/material.dart';

import 'motion.dart';

/// Wraps a list/feed item so it fades and slides up (12px) into place, with a
/// per-item delay ([Motion.stagger]) capped at [Motion.maxStaggered] so long
/// lists never accumulate a laggy cascade.
///
/// Uses a manual [AnimationController] because staggering by index is exactly
/// the case the implicit widgets can't express (each item needs its own
/// delayed start). The controller is always disposed. Under reduced motion it
/// shows the child immediately with no controller-driven animation.
///
/// Purely presentational: wrap an existing item widget with it — it changes
/// nothing about layout or behaviour, only how the item appears.
class StaggeredItem extends StatefulWidget {
  const StaggeredItem({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Motion.base);
    _curved = CurvedAnimation(parent: _controller, curve: Motion.entrance);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs MediaQuery (reduced motion), so it can't run in initState.
    if (_scheduled) return;
    _scheduled = true;

    if (Motion.reduceMotion(context)) {
      _controller.value = 1.0; // straight to final state, no motion
      return;
    }
    final delay = Motion.staggerDelay(context, widget.index);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: AnimatedBuilder(
        animation: _curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _curved.value) * Motion.slideOffset),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
