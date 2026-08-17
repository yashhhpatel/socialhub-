import 'package:flutter/material.dart';

import 'tokens/color_tokens.dart';

/// A soft, airy decorative background: a lavender gradient wash plus a few
/// blurred abstract "blob" shapes, inspired by the light-purple reference.
///
/// Purely decorative and non-interactive (wrapped in IgnorePointer). Stacks
/// [child] on top. Used behind the app shell content and the auth screens so
/// the whole product shares one calm, premium backdrop. In dark mode the
/// blobs are near-invisible, keeping dark surfaces clean.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.showBlobs = true});

  final Widget child;
  final bool showBlobs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [ColorTokens.neutralDark50, ColorTokens.neutralDark0]
              : const [
                  ColorTokens.gradientStart,
                  ColorTokens.gradientMid,
                  ColorTokens.gradientEnd,
                ],
        ),
      ),
      child: Stack(
        children: [
          if (showBlobs && !isDark)
            const Positioned.fill(
              child: IgnorePointer(child: _Blobs()),
            ),
          child,
        ],
      ),
    );
  }
}

class _Blobs extends StatelessWidget {
  const _Blobs();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: _Blob(size: 360, color: ColorTokens.blobViolet, opacity: 0.10),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _Blob(size: 420, color: ColorTokens.blobPink, opacity: 0.14),
        ),
        Positioned(
          top: 220,
          left: -60,
          child: _Blob(size: 220, color: ColorTokens.blobViolet, opacity: 0.06),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // A radial gradient fading to transparent gives a soft, blur-free glow
    // that is cheap to composite on web.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ),
      ),
    );
  }
}
