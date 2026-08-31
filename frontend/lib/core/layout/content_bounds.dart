import 'package:flutter/material.dart';

/// The maximum width the app's main content, top navigation, and footer all
/// share, so everything lines up to the same centred column on wide screens
/// instead of stretching from edge to edge.
///
/// Applied once each in AppShell (routed content), TopNavBar (nav content) and
/// AppFooter — change it here to reflow the whole site's content width.
const double kContentMaxWidth = 1200;

/// Horizontally centres [child] within [maxWidth]. Below that width the child
/// simply fills the available space, so pages stay responsive on tablet and
/// mobile (their own edge padding provides the side gutter there); above it,
/// the child is centred with equal gutters on both sides.
class ContentBounds extends StatelessWidget {
  const ContentBounds({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
