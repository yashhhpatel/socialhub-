import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/motion/skeleton.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/state/current_user_provider.dart';

/// A time-aware greeting for the top of the dashboard — leading accent tile
/// with a time-of-day glyph, then "Good Morning, <name>" over the date.
///
/// Styled from the existing dashboard idiom (see StatCard): the same accent-
/// tinted rounded-square tile, the same theme text roles and muted-text
/// treatment, and existing spacing tokens — no new colors, radii, or magic
/// spacing. The name comes from the current auth user (no new API); a shimmer
/// stands in while it loads, so "null" never shows.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final compact = Breakpoints.isMobile(context);

    final greeting = _greetingFor(DateTime.now());
    final dateLabel = DateFormat('EEE, MMM d y').format(DateTime.now());

    // Name is the only part that depends on the user; everything else renders
    // immediately. Shimmer while loading; a neutral fallback on error so the
    // greeting is never broken or shows "null".
    final userAsync = ref.watch(currentUserProvider);
    final greetingStyle =
        (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
            ?.copyWith(color: theme.colorScheme.onSurface);
    final Widget nameLine = userAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Skeleton(
          width: compact ? 96 : 120,
          height: (greetingStyle?.fontSize ?? 18),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      error: (_, __) => Text('there', style: _bold(greetingStyle)),
      data: (u) => Text(
        _displayName(u),
        style: _bold(greetingStyle),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final tileSize = compact ? 40.0 : 48.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Leading accent tile — same treatment as the dashboard StatCard tile.
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(greeting.icon, size: compact ? 20 : 22, color: accent),
        ),
        SizedBox(width: compact ? SpacingTokens.sm : SpacingTokens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${greeting.label}, ', style: greetingStyle),
                  Flexible(child: nameLine),
                ],
              ),
              SizedBox(height: compact ? 2 : SpacingTokens.xs),
              Text(
                dateLabel,
                style:
                    (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                        ?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle? _bold(TextStyle? base) => base?.copyWith(fontWeight: FontWeight.w700);

  /// Time-of-day greeting + glyph from device-local time.
  ({String label, IconData icon}) _greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour < 12) {
      return (label: 'Good Morning', icon: Icons.wb_sunny_outlined);
    }
    if (hour < 17) {
      return (label: 'Good Afternoon', icon: Icons.wb_twilight);
    }
    return (label: 'Good Evening', icon: Icons.dark_mode_outlined);
  }

  /// A friendly display name from the account. There is no name field (signup
  /// collects only email), so derive it from the email's local part — first
  /// token, capitalized. Never returns empty.
  String _displayName(CurrentUser user) {
    final local = user.email.split('@').first;
    final token = local
        .split(RegExp(r'[._+\-]'))
        .firstWhere((s) => s.isNotEmpty, orElse: () => local);
    if (token.isEmpty) return 'there';
    return token[0].toUpperCase() + token.substring(1);
  }
}
