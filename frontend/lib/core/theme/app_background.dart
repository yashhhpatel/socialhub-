import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The flat page backdrop behind the app shell and auth screens.
///
/// Midnight Studio has no gradients and no glow — surfaces are separated by
/// 1px borders on a solid near-black background — so this simply paints
/// [AppColors.background] under [child]. The `showBlobs` flag is retained for
/// call-site compatibility but is intentionally inert.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.showBlobs = true});

  final Widget child;
  final bool showBlobs;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: child,
    );
  }
}
