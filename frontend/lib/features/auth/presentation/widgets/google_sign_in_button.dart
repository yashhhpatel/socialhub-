import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';

/// Full-width "Continue with Google" button on a dark surface, with the
/// four-colour Google mark on the left. Styled to sit above the email field on
/// both auth screens; matches the app's radius and violet focus treatment.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceRaised,
          foregroundColor: theme.colorScheme.onSurface,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleGLogo(size: 18),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four-colour Google "G", drawn so it needs no asset or extra package.
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _GoogleGPainter());
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  double _rad(double deg) => deg * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.26;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(stroke / 2);
    final center = Offset(size.width / 2, size.height / 2);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Canvas angles: 0deg = east, positive = clockwise (y is down). Walking
    // clockwise from just below east: green (bottom) -> yellow (left) ->
    // red (top) -> blue (top-right), leaving a gap on the right for the bar.
    canvas.drawArc(rect, _rad(12), _rad(66), false, arc..color = _green);
    canvas.drawArc(rect, _rad(78), _rad(70), false, arc..color = _yellow);
    canvas.drawArc(rect, _rad(148), _rad(82), false, arc..color = _red);
    canvas.drawArc(rect, _rad(230), _rad(82), false, arc..color = _blue);

    // The blue crossbar: from the centre out to the right edge, at the
    // vertical midline — the defining stroke of the Google G.
    final barTop = center.dy - stroke / 2;
    final bar = Rect.fromLTRB(
      center.dx - stroke * 0.15,
      barTop,
      size.width,
      barTop + stroke,
    );
    canvas.drawRect(bar, Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(covariant _GoogleGPainter oldDelegate) => false;
}
