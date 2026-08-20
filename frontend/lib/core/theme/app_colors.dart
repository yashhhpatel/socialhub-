import 'package:flutter/material.dart';

/// Midnight Studio — the app's single colour source of truth.
///
/// A calm, near-black dark theme. Surfaces are separated by 1px borders, not
/// shadows (shadows are invisible on near-black). Accent is used sparingly —
/// one primary action per screen; everything else is neutral surface + text.
/// The three status colours are functional only: every scheduled post shows
/// its state with one of them, never decoratively.
abstract final class AppColors {
  const AppColors._();

  /// Page background.
  static const Color background = Color(0xFF0D0F14);

  /// Cards, sidebar.
  static const Color surface = Color(0xFF161A22);

  /// Modals, hover, dropdowns.
  static const Color surfaceRaised = Color(0xFF1F242E);

  /// All dividers and card outlines.
  static const Color border = Color(0xFF2A303C);

  /// Headings and body.
  static const Color textPrimary = Color(0xFFE8EAED);

  /// Timestamps, hints, labels.
  static const Color textMuted = Color(0xFF8A92A3);

  /// Primary buttons, active nav, links.
  static const Color accent = Color(0xFF6C5CE7);

  /// Hover and focus rings.
  static const Color accentHover = Color(0xFFA29BFE);

  /// Published posts.
  static const Color success = Color(0xFF26D07C);

  /// Queued / pending posts.
  static const Color warning = Color(0xFFFFB020);

  /// Failed posts.
  static const Color error = Color(0xFFFF5C5C);
}
