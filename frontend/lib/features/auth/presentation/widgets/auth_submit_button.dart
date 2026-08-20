import 'package:flutter/material.dart';

import '../../../../core/motion/motion_switcher.dart';
import '../../../../core/motion/tap_scale.dart';

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          // Animate the label ↔ spinner swap instead of a hard cut.
          child: MotionSwitcher(
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label, key: const ValueKey('label')),
          ),
        ),
      ),
    );
  }
}
