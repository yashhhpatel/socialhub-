import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/tokens/spacing_tokens.dart';
import '../content_bounds.dart';

// Footer chrome, from the Midnight Studio palette: a surface backdrop with a
// 1px border, primary text and muted secondary text.
const _footerBg = AppColors.surface;
const _footerText = AppColors.textPrimary; // brand + links
const _footerMuted = AppColors.textMuted; // tagline, titles, copyright
const _footerDivider = AppColors.border; // border + divider

/// Global site footer, rendered once by AppShell so every page — present and
/// future — shares the same structure and styling.
///
/// Organised into labelled columns (Product, Workspace, Company) that repeat
/// the important header destinations plus the legal/informational pages a
/// SaaS product needs, with a brand block and a bottom bar carrying the
/// copyright and the top-level legal links. Columns wrap on narrow screens.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static const _product = <_FooterLink>[
    _FooterLink('Dashboard', '/dashboard'),
    _FooterLink('Content', '/content'),
    _FooterLink('Calendar', '/calendar'),
    _FooterLink('Analytics', '/analytics'),
    _FooterLink('Templates', '/templates'),
    _FooterLink('Marketplace', '/marketplace'),
  ];

  static const _workspace = <_FooterLink>[
    _FooterLink('Team', '/team'),
    _FooterLink('Organizations', '/organizations'),
    _FooterLink('Brand Kit', '/brand-kit'),
    _FooterLink('White Label', '/white-label'),
    _FooterLink('Billing', '/billing'),
    _FooterLink('Settings', '/settings'),
  ];

  static const _company = <_FooterLink>[
    _FooterLink('About Us', '/about'),
    _FooterLink('Contact Us', '/contact'),
    _FooterLink('Security', '/security'),
    _FooterLink('Help / Support', '/help'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: _footerBg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.xl,
          vertical: SpacingTokens.xl,
        ),
        // Centre the whole footer within a max width so it reads as a single
        // centred block on wide screens, consistent on every page.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            // ignore: prefer_const_constructors, prefer_const_literals_to_create_immutables
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: SpacingTokens.xl * 2,
                  runSpacing: SpacingTokens.xl,
                  children: [
                    _BrandBlock(),
                    _FooterColumn(title: 'Product', links: _product),
                    _FooterColumn(title: 'Workspace', links: _workspace),
                    _FooterColumn(title: 'Company', links: _company),
                  ],
                ),
                SizedBox(height: SpacingTokens.xl),
                Divider(color: _footerDivider, height: 1),
                SizedBox(height: SpacingTokens.md),
                _BottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.hub_outlined,
                  size: 25,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: SpacingTokens.md),
              Text(
                'SocialHub',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                  color: _footerText,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Plan, create, and publish across every social channel — from one calm workspace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _footerMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: _footerMuted,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
              child: _FooterLinkText(link: link),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: _footerMuted);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: SpacingTokens.lg,
      runSpacing: SpacingTokens.sm,
      children: [
        Text('Copyright © 2026 SocialHub. All rights reserved.', style: muted),
        const Wrap(
          spacing: SpacingTokens.lg,
          runSpacing: SpacingTokens.xs,
          children: [
            _FooterLinkText(link: _FooterLink('Privacy Policy', '/privacy')),
            _FooterLinkText(link: _FooterLink('Terms of Service', '/terms')),
            _FooterLinkText(link: _FooterLink('Security', '/security')),
          ],
        ),
      ],
    );
  }
}

class _FooterLinkText extends StatelessWidget {
  const _FooterLinkText({required this.link});

  final _FooterLink link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go(link.route),
      borderRadius: BorderRadius.circular(4),
      child: Text(
        link.label,
        style: theme.textTheme.bodyMedium?.copyWith(color: _footerText),
      ),
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.route);
  final String label;
  final String route;
}
