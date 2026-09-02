import 'package:flutter/material.dart';

import '../../theme/breakpoints.dart';
import '../../theme/tokens/spacing_tokens.dart';

/// The shared page header used at the top of every main screen — a large,
/// centered title with an optional subtitle line, and optional trailing
/// actions (e.g. a refresh icon or a primary button).
///
/// Centered and enlarged in one place so every page inherits the same
/// treatment: `headlineLarge` title + `titleMedium` subtitle, both
/// horizontally centered so multi-line values stay centered too.
///
/// Leading/trailing actions are preserved from the pages that had them. On
/// desktop / tablet they sit pinned to the left ([leading]) and right
/// ([trailing]) of the centered title; on mobile they drop below the title
/// (centered) so a wide button never overlaps the text. Pass a
/// `Row(mainAxisSize: MainAxisSize.min, …)` for more than one action on a side.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Optional action(s) pinned to the LEFT of the centered title on desktop.
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.xs),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ],
    );

    // Full-width so "centered" means centered on the page, not just within the
    // intrinsic width of the text.
    final fullWidthTexts = SizedBox(width: double.infinity, child: texts);

    if (leading == null && trailing == null) return fullWidthTexts;

    // Mobile: stack the actions beneath the centered title so a wide button
    // can't collide with the text on narrow widths.
    if (Breakpoints.isMobile(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          fullWidthTexts,
          const SizedBox(height: SpacingTokens.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: SpacingTokens.sm,
            runSpacing: SpacingTokens.sm,
            children: [
              if (leading != null) leading!,
              if (trailing != null) trailing!,
            ],
          ),
        ],
      );
    }

    // Desktop / tablet: title centered across the full width, actions pinned to
    // the left/right and vertically centered against the title block.
    return Stack(
      alignment: Alignment.center,
      children: [
        fullWidthTexts,
        if (leading != null)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: leading,
            ),
          ),
        if (trailing != null)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ),
      ],
    );
  }
}
