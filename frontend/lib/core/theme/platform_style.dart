import 'package:flutter/material.dart';

/// Brand identity for a social platform, keyed by the API's lowercase platform
/// string (`instagram`, `facebook`, `threads`, `x`, `linkedin`).
///
/// Centralised so the analytics, calendar and account views all show the same
/// icon, colour and label for a platform instead of each re-deriving them. The
/// colours are the platforms' own brand colours (intentionally not app theme
/// tokens — a brand mark is the same in any theme), matching the values the
/// analytics dashboard already used; the icons match the account cards'
/// existing mapping.
class PlatformStyle {
  const PlatformStyle._();

  /// Properly-cased brand name for a platform ("linkedin" → "LinkedIn",
  /// "x" → "X"). Falls back to a title-cased form for anything unknown.
  static String label(String platform) {
    switch (platform) {
      case 'instagram':
        return 'Instagram';
      case 'facebook':
        return 'Facebook';
      case 'threads':
        return 'Threads';
      case 'x':
        return 'X';
      case 'linkedin':
        return 'LinkedIn';
      default:
        return platform.isEmpty
            ? platform
            : '${platform[0].toUpperCase()}${platform.substring(1)}';
    }
  }

  /// The Material icon used for a platform across the app.
  static IconData icon(String platform) {
    switch (platform) {
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'facebook':
        return Icons.facebook;
      case 'threads':
        return Icons.tag;
      case 'x':
        return Icons.alternate_email;
      case 'linkedin':
        return Icons.business_center_outlined;
      default:
        return Icons.public;
    }
  }

  /// A stable, distinct brand colour per platform. Unknown platforms fall back
  /// to the theme's primary so nothing is ever colourless.
  static Color color(String platform, ColorScheme scheme) {
    switch (platform) {
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'threads':
        return const Color(0xFF444444);
      case 'x':
        return const Color(0xFF1DA1F2);
      case 'linkedin':
        return const Color(0xFF0A66C2);
      default:
        return scheme.primary;
    }
  }
}
