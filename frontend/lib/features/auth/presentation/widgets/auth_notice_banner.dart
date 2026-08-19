import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/color_tokens.dart';

/// Success / informational counterpart to [AuthErrorBanner] (Phase 17.1),
/// used to confirm actions like "reset link sent" or "email verified". Styled
/// in the brand primary rather than the error colour so it reads as good news.
class AuthNoticeBanner extends StatelessWidget {
  const AuthNoticeBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ColorTokens.brandPrimary.withOpacity(0.1),
        border: Border.all(color: ColorTokens.brandPrimary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: ColorTokens.brandPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ColorTokens.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
