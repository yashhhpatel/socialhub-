import 'package:flutter/material.dart';

import '../../core/theme/tokens/spacing_tokens.dart';

/// One reusable screen for SocialHub's static informational and legal pages
/// (About, Contact, Security, Help, Privacy, Terms). Content is data-driven
/// from [infoPages], so adding a page is a map entry plus a route — the
/// layout, theme, header and footer all come for free.
class InfoPageScreen extends StatelessWidget {
  const InfoPageScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = infoPages[slug];

    if (page == null) {
      return Padding(
        padding: const EdgeInsets.all(SpacingTokens.lg),
        child: Text('Page not found.', style: theme.textTheme.headlineMedium),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(page.title, style: theme.textTheme.headlineLarge),
              const SizedBox(height: SpacingTokens.xs),
              Text(
                page.intro,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.xl),
              for (final section in page.sections) ...[
                Text(section.heading, style: theme.textTheme.titleLarge),
                const SizedBox(height: SpacingTokens.sm),
                Text(
                  section.body,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                const SizedBox(height: SpacingTokens.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InfoSection {
  const InfoSection(this.heading, this.body);
  final String heading;
  final String body;
}

class InfoPage {
  const InfoPage({
    required this.title,
    required this.intro,
    required this.sections,
  });
  final String title;
  final String intro;
  final List<InfoSection> sections;
}

/// Content for each static page. Kept intentionally plain and honest — real
/// product copy, not legal advice — and easy to expand later.
const Map<String, InfoPage> infoPages = {
  'about': InfoPage(
    title: 'About SocialHub',
    intro: 'One calm workspace to plan, create, and publish across every channel.',
    sections: [
      InfoSection(
        'What we do',
        'SocialHub helps teams design content once and publish it everywhere — '
            'with a shared calendar, reusable templates and brand kits, an AI '
            'assistant for captions and hashtags, and analytics to see what '
            'works. Everything lives in a single, organised place instead of '
            'being scattered across tools.',
      ),
      InfoSection(
        'Who it\'s for',
        'From solo creators to marketing teams and agencies managing many '
            'organizations, SocialHub scales with roles, approvals, and '
            'white-label branding.',
      ),
    ],
  ),
  'contact': InfoPage(
    title: 'Contact Us',
    intro: 'We\'d love to hear from you.',
    sections: [
      InfoSection(
        'General enquiries',
        'Email us at hello@socialhub.example and we\'ll get back to you within '
            'two business days.',
      ),
      InfoSection(
        'Support',
        'For help with your account or a technical issue, visit Help / Support '
            'or email support@socialhub.example.',
      ),
    ],
  ),
  'security': InfoPage(
    title: 'Security',
    intro: 'How SocialHub protects your data and your connected accounts.',
    sections: [
      InfoSection(
        'Your connected accounts',
        'Access tokens for connected social platforms are encrypted before they '
            'are stored, and are never exposed through the API. You can '
            'disconnect any account at any time from Settings.',
      ),
      InfoSection(
        'Access control',
        'Every organization has role-based access (owner, admin, editor, '
            'viewer), and sensitive actions are restricted to the appropriate '
            'roles. Enterprise plans add SSO and audit logging.',
      ),
      InfoSection(
        'Reporting an issue',
        'Found a vulnerability? Email security@socialhub.example — we take '
            'reports seriously and will respond promptly.',
      ),
    ],
  ),
  'help': InfoPage(
    title: 'Help / Support',
    intro: 'Answers and assistance for getting the most out of SocialHub.',
    sections: [
      InfoSection(
        'Getting started',
        'Create an account, connect your social platforms in Settings, design '
            'your first post in Content, and schedule it from the Calendar.',
      ),
      InfoSection(
        'Need a hand?',
        'Browse this help area or reach the team at support@socialhub.example. '
            'We\'re happy to help.',
      ),
    ],
  ),
  'privacy': InfoPage(
    title: 'Privacy Policy',
    intro: 'This policy explains what SocialHub collects, how it is used, and '
        'how you can remove your data — including data obtained from platforms '
        'you connect, such as Facebook, Instagram, and Threads.',
    sections: [
      InfoSection(
        'Information we collect',
        'Account details (name, email, organization), the content you create, '
            'and basic usage data to operate and improve the product.',
      ),
      InfoSection(
        'Data from connected platforms',
        'When you connect a social account, we receive an access token and the '
            'account identity needed to publish on your behalf — for example your '
            'platform user ID, page or profile ID, and username. For Meta '
            'platforms (Facebook, Instagram, Threads) we request only the '
            'permissions required to list the pages or profiles you manage and to '
            'publish the posts you schedule. We do not collect your Meta password, '
            'and we do not read private messages. Access tokens are encrypted '
            'before they are stored and are never exposed through our API.',
      ),
      InfoSection(
        'How we use it',
        'To provide the service — publishing your content, generating AI '
            'suggestions, and showing your analytics — and to keep your account '
            'secure. We do not sell your personal data, and we do not use data '
            'from connected platforms for advertising.',
      ),
      InfoSection(
        'Removing your data',
        'You can disconnect any platform at any time from Settings, which deletes '
            'the stored token and account for that platform. For Meta platforms '
            'you can also remove SocialHub from the app\'s settings on Facebook, '
            'Instagram, or Threads; Meta then notifies us and we automatically '
            'delete the data associated with your platform account. To request '
            'deletion of all your data, use the "Remove App" option on the '
            'platform or email privacy@socialhub.example — we confirm each request '
            'with a tracking code and complete deletion promptly.',
      ),
      InfoSection(
        'Your choices',
        'You can disconnect platforms, export or delete your content, and close '
            'your account at any time. Contact us with any privacy request.',
      ),
    ],
  ),
  'terms': InfoPage(
    title: 'Terms of Service',
    intro: 'The basics of using SocialHub. By using the product you agree to these terms.',
    sections: [
      InfoSection(
        'Using SocialHub',
        'You are responsible for the content you publish and for complying with '
            'the terms of the social platforms you connect. Use the service '
            'lawfully and don\'t attempt to disrupt or abuse it.',
      ),
      InfoSection(
        'Your content',
        'You keep ownership of your content. You grant SocialHub the permissions '
            'needed to store it and publish it on your behalf to the accounts '
            'you connect.',
      ),
      InfoSection(
        'Connected platforms',
        'When you connect a third-party platform such as Facebook, Instagram, or '
            'Threads, your use of that platform through SocialHub is also governed '
            'by that platform\'s own terms and policies. You are responsible for '
            'holding the rights to publish the content you send to it, and you can '
            'revoke SocialHub\'s access at any time from the platform or from '
            'Settings.',
      ),
      InfoSection(
        'Availability',
        'We work to keep SocialHub reliable but provide it "as is". We may '
            'update these terms; continued use means you accept the changes.',
      ),
    ],
  ),
};
