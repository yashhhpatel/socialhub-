import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/staggered_item.dart';
import '../../../../core/motion/tap_scale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/theme/platform_style.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';

/// The public landing page (shown at `/` when signed out). A marketing-style
/// overview of what SocialHub does, with Login / Sign-up CTAs and links into
/// the real (browsable) product pages. Signed-in users never see this — the
/// router redirects `/` to `/dashboard` for them.
///
/// Renders inside AppShell, so it carries the app's top nav and footer. Uses
/// only real product facts (platforms, features) — no fabricated metrics.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        children: [
          _Hero(),
          _PlatformStrip(),
          _FeatureGrid(),
          _HowItWorks(),
          _FinalCta(),
        ],
      ),
    );
  }
}

/// Constrains a section's content to a comfortable max width and centres it,
/// with generous vertical rhythm — the backbone of the landing layout.
class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.color,
    this.vertical = 64,
  });

  final Widget child;
  final Color? color;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    final v = Breakpoints.isMobile(context) ? vertical * 0.6 : vertical;
    return Container(
      width: double.infinity,
      color: color,
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.lg,
        vertical: v,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: child,
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Breakpoints.isMobile(context);

    final headline = RichText(
      textAlign: isMobile ? TextAlign.center : TextAlign.start,
      text: TextSpan(
        style: theme.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.1,
          letterSpacing: -0.5,
          fontSize: isMobile ? 34 : 52,
        ),
        children: [
          // Two contrasting theme colours across the headline.
          TextSpan(
            text: 'Create once.\n',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          const TextSpan(
            text: 'Publish everywhere.',
            style: TextStyle(color: AppColors.accentHover),
          ),
        ],
      ),
    );

    final copy = Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Badge(text: 'One workspace for every platform'),
        const SizedBox(height: SpacingTokens.lg),
        headline,
        const SizedBox(height: SpacingTokens.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'Design posts and carousels, schedule them across Instagram, '
            'Facebook, Threads, X and LinkedIn, and see what actually '
            'performs — all from one calm, fast workspace.',
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.xl),
        Wrap(
          spacing: SpacingTokens.md,
          runSpacing: SpacingTokens.sm,
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          children: [
            FilledButton(
              onPressed: () => context.go('/register'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: const Text('Get started free'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/dashboard'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: const Text('Explore the app'),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          'No account needed to look around — sign in when you want to publish.',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return _Section(
      vertical: 80,
      child: isMobile
          ? StaggeredItem(index: 0, child: copy)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: StaggeredItem(index: 0, child: copy)),
                const SizedBox(width: SpacingTokens.xxl),
                const Expanded(
                  child: StaggeredItem(index: 1, child: _HeroPreview()),
                ),
              ],
            ),
    );
  }
}

/// A lightweight, abstract product visual — not a screenshot, just tinted
/// cards suggesting the composer + schedule + analytics, so the hero has a
/// right-hand anchor without shipping a heavy asset.
class _HeroPreview extends StatelessWidget {
  const _HeroPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(IconData icon, String label, Color color) => Container(
          padding: const EdgeInsets.all(SpacingTokens.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 9, width: 120, decoration: _bar(theme)),
                    const SizedBox(height: 6),
                    Container(height: 9, width: 70, decoration: _bar(theme)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withOpacity(0.18),
            theme.colorScheme.surface.withOpacity(0.0),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          tile(Icons.edit_outlined, 'Compose', AppColors.accent),
          const SizedBox(height: SpacingTokens.md),
          tile(Icons.calendar_month_outlined, 'Schedule', AppColors.warning),
          const SizedBox(height: SpacingTokens.md),
          tile(Icons.insights_outlined, 'Analyze', AppColors.success),
        ],
      ),
    );
  }

  BoxDecoration _bar(ThemeData theme) => BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 14,
            color: AppColors.accentHover,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.accentHover,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The supported networks, using the shared platform brand icons/colours.
class _PlatformStrip extends StatelessWidget {
  const _PlatformStrip();

  static const _platforms = [
    'instagram',
    'facebook',
    'threads',
    'x',
    'linkedin',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      color: theme.colorScheme.surface.withOpacity(0.4),
      vertical: 36,
      child: Column(
        children: [
          Text(
            'PUBLISH TO EVERY MAJOR NETWORK',
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          Wrap(
            spacing: SpacingTokens.xl,
            runSpacing: SpacingTokens.md,
            alignment: WrapAlignment.center,
            children: [
              for (final p in _platforms)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PlatformStyle.icon(p),
                      color: PlatformStyle.color(p, theme.colorScheme),
                      size: 22,
                    ),
                    const SizedBox(width: SpacingTokens.sm),
                    Text(
                      PlatformStyle.label(p),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.title, this.body, this.path, this.color);
  final IconData icon;
  final String title;
  final String body;
  final String path;
  final Color color;
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const _features = [
    _Feature(
      Icons.grid_view_outlined,
      'Composer & carousels',
      'Design single posts or multi-image carousels once, tailored per platform.',
      '/content',
      AppColors.accent,
    ),
    _Feature(
      Icons.calendar_month_outlined,
      'Visual scheduling',
      'Plan a month or a week ahead on a real calendar and let posts go out on time.',
      '/calendar',
      AppColors.warning,
    ),
    _Feature(
      Icons.insights_outlined,
      'Cross-platform analytics',
      'See impressions, reach and engagement across every connected account in one view.',
      '/analytics',
      AppColors.success,
    ),
    _Feature(
      Icons.auto_awesome_outlined,
      'AI assistant',
      'Generate captions and hashtags, and find the best time to post.',
      '/ai-assistant',
      AppColors.accentHover,
    ),
    _Feature(
      Icons.perm_media_outlined,
      'Media library',
      'Upload once and reuse hosted images and video across all your posts.',
      '/media-library',
      Color(0xFF1DA1F2),
    ),
    _Feature(
      Icons.hub_outlined,
      'Connected accounts',
      'Link Instagram, Facebook, Threads, X and LinkedIn and publish to them together.',
      '/settings',
      Color(0xFF0A66C2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cols = Breakpoints.isDesktop(context)
        ? 3
        : Breakpoints.isTablet(context)
            ? 2
            : 1;

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Everything you need to run social',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Explore any of these now — sign in only when you publish.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.xl),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: SpacingTokens.lg,
            mainAxisSpacing: SpacingTokens.lg,
            childAspectRatio: cols == 1 ? 2.6 : 1.25,
            children: [
              for (var i = 0; i < _features.length; i++)
                StaggeredItem(
                  index: i,
                  child: _FeatureCard(feature: _features[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TapScale(
      hoverElevation: true,
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.go(feature.path),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: feature.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(feature.icon, color: feature.color, size: 22),
                ),
                const SizedBox(height: SpacingTokens.md),
                Text(
                  feature.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: SpacingTokens.xs),
                Expanded(
                  child: Text(
                    feature.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: SpacingTokens.sm),
                Row(
                  children: [
                    Text(
                      'Explore',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      '1',
      Icons.edit_outlined,
      'Compose',
      'Write or design your post — or a full carousel — once.'
    ),
    (
      '2',
      Icons.calendar_month_outlined,
      'Schedule',
      'Pick the platforms and the time; queue it on the calendar.'
    ),
    (
      '3',
      Icons.insights_outlined,
      'Analyze',
      'Watch performance roll in and double down on what works.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cols = Breakpoints.isMobile(context) ? 1 : 3;
    return _Section(
      color: theme.colorScheme.surface.withOpacity(0.4),
      child: Column(
        children: [
          Text(
            'From idea to insight in three steps',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: SpacingTokens.xl),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: SpacingTokens.lg,
            mainAxisSpacing: SpacingTokens.lg,
            childAspectRatio: cols == 1 ? 3.4 : 1.1,
            children: [
              for (var i = 0; i < _steps.length; i++)
                StaggeredItem(
                  index: i,
                  child: _StepCard(
                    number: _steps[i].$1,
                    icon: _steps[i].$2,
                    title: _steps[i].$3,
                    body: _steps[i].$4,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });
  final String number;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.accent.withOpacity(0.15),
                child: Text(
                  number,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.accentHover,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Breakpoints.isMobile(context);
    return _Section(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.xl,
          vertical: isMobile ? SpacingTokens.xl : SpacingTokens.xxl,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.accentHover],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Text(
              'Ready to grow your audience?',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              'Create your free workspace and publish your first post today.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: Colors.white.withOpacity(0.9)),
            ),
            const SizedBox(height: SpacingTokens.lg),
            Wrap(
              spacing: SpacingTokens.md,
              runSpacing: SpacingTokens.sm,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: () => context.go('/register'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Get started free'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Log in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
