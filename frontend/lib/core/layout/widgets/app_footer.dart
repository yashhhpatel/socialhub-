import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens/color_tokens.dart';
import '../../theme/tokens/spacing_tokens.dart';

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
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.xl,
          vertical: SpacingTokens.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Wrap(
              spacing: SpacingTokens.xl * 2,
              runSpacing: SpacingTokens.xl,
              children: [
                _BrandBlock(),
                _FooterColumn(title: 'Product', links: _product),
                _FooterColumn(title: 'Workspace', links: _workspace),
                _FooterColumn(title: 'Company', links: _company),
              ],
            ),
            const SizedBox(height: SpacingTokens.xl),
            Divider(color: theme.dividerColor, height: 1),
            const SizedBox(height: SpacingTokens.md),
            const _BottomBar(),
          ],
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
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ColorTokens.brandPrimary, ColorTokens.blobPink],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.hub_outlined, size: 17, color: Colors.white),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Text('SocialHub', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Plan, create, and publish across every social channel — from one calm workspace.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
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
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
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
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.route);
  final String label;
  final String route;
}
