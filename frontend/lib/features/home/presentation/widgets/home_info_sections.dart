import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/staggered_item.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/platform_style.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';

/// The informational "what SocialHub is and does" content on the Home page,
/// shown to everyone (signed in or out) so a new visitor understands the
/// product within a few seconds without navigating away.
///
/// Every capability described here maps to a feature that already exists in the
/// app — multi-platform publishing, the scheduling calendar, the AI assistant,
/// the design editor + templates/marketplace, the media library, analytics,
/// team collaboration and the brand kit. Nothing here is aspirational copy.
///
/// Purely presentational: theme tokens, [PlatformStyle] and existing motion
/// only — no new endpoints or business logic.
class HomeInfoSections extends StatelessWidget {
  const HomeInfoSections({super.key, required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StaggeredItem(index: 0, child: _WhatIsSocialHub()),
        const SizedBox(height: SpacingTokens.xxl),
        const StaggeredItem(index: 1, child: _HowItWorks()),
        const SizedBox(height: SpacingTokens.xxl),
        const StaggeredItem(index: 2, child: _KeyFeatures()),
        const SizedBox(height: SpacingTokens.xxl),
        const StaggeredItem(index: 3, child: _SupportedPlatforms()),
        const SizedBox(height: SpacingTokens.xxl),
        StaggeredItem(index: 4, child: _CtaBand(loggedIn: loggedIn)),
      ],
    );
  }
}

/// A centred section heading (title + supporting line) reused by each section.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: SpacingTokens.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lays out [cards] in evenly-sized columns that reflow to fewer columns as the
/// available width shrinks — responsive on desktop, tablet and mobile.
class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.cards,
    required this.minItemWidth,
    this.maxColumns = 4,
  });

  final List<Widget> cards;
  final double minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = SpacingTokens.md;
        var columns = (constraints.maxWidth / minItemWidth).floor();
        columns = columns.clamp(1, maxColumns);
        final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: itemWidth, child: card),
          ],
        );
      },
    );
  }
}

/// Bordered surface card with a coloured icon chip, a title and a short body —
/// the shared shape for the steps and feature grids.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// "What is SocialHub" — a single value-proposition band.
class _WhatIsSocialHub extends StatelessWidget {
  const _WhatIsSocialHub();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.xl,
        vertical: SpacingTokens.xxl,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withOpacity(0.16),
            AppColors.accent.withOpacity(0.04),
          ],
        ),
      ),
      child: Column(
        children: [
          const _Eyebrow('WHAT IS SOCIALHUB'),
          const SizedBox(height: SpacingTokens.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              'One workspace for your entire social media workflow',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              'SocialHub is an all-in-one social media management platform. Design '
              'posts, schedule them across every major network, let AI help with '
              'captions and hashtags, and track how they perform — all from a '
              'single place, without juggling separate tools.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase pill label used as a section eyebrow.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.accentHover,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// "How SocialHub works" — the Create → Schedule → Publish → Analyze flow.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      Icons.edit_outlined,
      AppColors.accent,
      '1. Create',
      'Design eye-catching posts in the built-in editor, start from a saved '
          'template, or reuse assets from your media library.',
    ),
    (
      Icons.calendar_month_outlined,
      AppColors.warning,
      '2. Schedule',
      'Plan your content on a calendar and queue it for the best times across '
          'every connected account.',
    ),
    (
      Icons.send_outlined,
      AppColors.success,
      '3. Publish',
      'Publish to Instagram, Facebook, X, LinkedIn and Threads at once — now, '
          'or automatically at the scheduled time.',
    ),
    (
      Icons.insights_outlined,
      Color(0xFF1DA1F2),
      '4. Analyze',
      'Track reach, engagement and performance across platforms to see what '
          'works and grow your audience.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SectionHeading(
          title: 'How SocialHub works',
          subtitle: 'Simple steps to smarter social media management.',
        ),
        const SizedBox(height: SpacingTokens.xl),
        _CardsGrid(
          minItemWidth: 240,
          cards: [
            for (final (icon, color, title, body) in _steps)
              _InfoCard(icon: icon, color: color, title: title, body: body),
          ],
        ),
      ],
    );
  }
}

/// "Everything you need" — the real feature set, as cards.
class _KeyFeatures extends StatelessWidget {
  const _KeyFeatures();

  static const _features = [
    (
      Icons.share_outlined,
      AppColors.accent,
      'Multi-platform publishing',
      'Post to Instagram, Facebook, X, LinkedIn and Threads at once — including '
          'multi-image carousels.',
    ),
    (
      Icons.event_available_outlined,
      AppColors.warning,
      'Smart scheduling & calendar',
      'Plan a content calendar and schedule posts for the best times, with '
          'month, week and list views.',
    ),
    (
      Icons.auto_awesome_outlined,
      AppColors.accentHover,
      'AI content assistant',
      'Generate captions and hashtags, analyse a design\'s viral potential, and '
          'get suggested posting times.',
    ),
    (
      Icons.dashboard_customize_outlined,
      Color(0xFFE1306C),
      'Design studio & templates',
      'Create designs on a canvas editor, save reusable templates, and browse '
          'the community marketplace.',
    ),
    (
      Icons.perm_media_outlined,
      Color(0xFF1DA1F2),
      'Media library',
      'Upload and organise images and videos once, then reuse their hosted URLs '
          'across any post.',
    ),
    (
      Icons.insights_outlined,
      AppColors.success,
      'Analytics & insights',
      'See reach, engagement and performance per platform, from the real data '
          'of your connected accounts.',
    ),
    (
      Icons.groups_outlined,
      Color(0xFF0A66C2),
      'Team collaboration',
      'Invite teammates with roles, and route posts through approvals before '
          'they go live.',
    ),
    (
      Icons.palette_outlined,
      AppColors.warning,
      'Brand kit',
      'Keep your colours, fonts and logo in one place and apply them to any '
          'design in a click.',
    ),
    (
      Icons.folder_copy_outlined,
      AppColors.accent,
      'Content management',
      'Manage drafts, scheduled and published posts together in one organised '
          'library.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SectionHeading(
          title: 'Everything you need to succeed',
          subtitle: 'A complete toolkit for managing social media, end to end.',
        ),
        const SizedBox(height: SpacingTokens.xl),
        _CardsGrid(
          minItemWidth: 300,
          maxColumns: 3,
          cards: [
            for (final (icon, color, title, body) in _features)
              _InfoCard(icon: icon, color: color, title: title, body: body),
          ],
        ),
      ],
    );
  }
}

/// "Supported platforms" — the five networks SocialHub publishes to, styled
/// with their brand identity from [PlatformStyle].
class _SupportedPlatforms extends StatelessWidget {
  const _SupportedPlatforms();

  static const _platforms = [
    'instagram',
    'facebook',
    'x',
    'linkedin',
    'threads',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const _SectionHeading(
          title: 'Publish everywhere your audience is',
          subtitle:
              'Connect your accounts and post to all the major networks from '
              'one place.',
        ),
        const SizedBox(height: SpacingTokens.xl),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: SpacingTokens.md,
          runSpacing: SpacingTokens.md,
          children: [
            for (final p in _platforms)
              _PlatformChip(
                icon: PlatformStyle.icon(p),
                color: PlatformStyle.color(p, scheme),
                label: PlatformStyle.label(p),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.lg,
        vertical: SpacingTokens.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: SpacingTokens.sm),
          Text(label, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Closing call-to-action band. Adapts its button to the auth state so it never
/// dead-ends a signed-in user on a "sign up" prompt.
class _CtaBand extends StatelessWidget {
  const _CtaBand({required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.xl,
        vertical: SpacingTokens.xxl,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.accent, AppColors.accentHover],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Ready to grow your social presence?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Plan, create, schedule and analyse — all in one place.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          FilledButton(
            onPressed: () => context.go(loggedIn ? '/dashboard' : '/register'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.xl,
                vertical: SpacingTokens.md,
              ),
            ),
            child: Text(loggedIn ? 'Go to dashboard' : 'Create your account'),
          ),
        ],
      ),
    );
  }
}
