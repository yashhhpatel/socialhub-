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

    // Scrollable: the pages are now long enough to overflow shorter windows.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.lg,
        vertical: SpacingTokens.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(page.title, style: theme.textTheme.headlineLarge),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                page.intro,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: SpacingTokens.xl),
              for (final section in page.sections)
                _SectionView(section: section),
              // A little breathing room below the last section.
              const SizedBox(height: SpacingTokens.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders one section: a heading, an optional paragraph, and an optional
/// bulleted list — with consistent spacing between every part.
class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final InfoSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.heading, style: theme.textTheme.titleLarge),
          const SizedBox(height: SpacingTokens.sm),
          if (section.body.isNotEmpty)
            Text(
              section.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          if (section.bullets.isNotEmpty) ...[
            if (section.body.isNotEmpty)
              const SizedBox(height: SpacingTokens.sm),
            for (final bullet in section.bullets)
              _Bullet(text: bullet),
          ],
        ],
      ),
    );
  }
}

/// A single list item: a dot marker aligned to the first line, then the text.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: SpacingTokens.sm),
            child: Icon(
              Icons.circle,
              size: 6,
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class InfoSection {
  const InfoSection(this.heading, this.body, {this.bullets = const []});
  final String heading;

  /// Optional paragraph. May be empty when the section is purely a list.
  final String body;

  /// Optional bulleted list, shown under [body].
  final List<String> bullets;
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
        'SocialHub brings your whole social workflow into one place. Design a '
            'post once, adapt it for each network automatically, schedule it on a '
            'shared calendar, and see how it performs — without juggling a dozen '
            'browser tabs and separate tools. It is built to feel calm and '
            'focused, so planning a week of content is a quick, organised job '
            'rather than a scramble.',
      ),
      InfoSection(
        'Everything you can do',
        '',
        bullets: [
          'Design studio — a canvas editor for images, text, and shapes, with '
              'reusable templates and a community template marketplace.',
          'Create Post & Publish — upload images and videos to a media library '
              'that persists across sessions, then publish them straight away.',
          'Carousels — combine several images into one post (a single image '
              'works too) for the platforms that support them.',
          'Smart scheduling — plan everything on a shared calendar and let '
              'SocialHub publish each post at the time you choose.',
          'AI assistant — generate captions and hashtags, rewrite the tone, and '
              'check a post\'s "viral score" before it goes live.',
          'Multi-platform publishing — send the same design to several accounts '
              'at once, each rendered to that platform\'s format.',
          'Analytics — reach and engagement per platform, pulled automatically '
              'from your connected accounts.',
          'Team workflows — roles, approvals, and comments so work can be '
              'reviewed before anything is published.',
          'Brand kits & white-label — keep every post on-brand, and agencies '
              'can present the whole workspace as their own.',
        ],
      ),
      InfoSection(
        'Platforms we support',
        'Connect the networks your audience actually uses and publish to all of '
            'them from one place:',
        bullets: [
          'Instagram',
          'Threads',
          'Facebook',
          'X (Twitter)',
          'LinkedIn',
        ],
      ),
      InfoSection(
        'Who it\'s for',
        'From solo creators posting to a couple of accounts, to marketing teams '
            'running an always-on calendar, to agencies managing many client '
            'organizations at once — SocialHub scales with you through roles, '
            'approvals, multiple workspaces, and white-label branding.',
      ),
      InfoSection(
        'How we think about it',
        '',
        bullets: [
          'Calm and focused — fewer tabs, clearer defaults, less noise.',
          'Honest analytics — real numbers from your connected accounts, never '
              'inflated vanity metrics.',
          'Your data stays yours — we never sell it, and you can export or '
              'delete it at any time.',
          'Built for teams — review, approve, and publish together without '
              'stepping on each other.',
        ],
      ),
    ],
  ),
  'contact': InfoPage(
    title: 'Contact Us',
    intro: 'We\'d love to hear from you — whether it\'s a question, a problem, '
        'or an idea for what we should build next.',
    sections: [
      InfoSection(
        'General enquiries',
        'For questions about SocialHub, feedback, or anything that doesn\'t fit '
            'the categories below, email hello@socialhub.example. We read every '
            'message and reply within two business days.',
      ),
      InfoSection(
        'Support',
        'Having trouble with your account or hitting a technical issue? Start '
            'with the Help / Support page for step-by-step answers, or email '
            'support@socialhub.example with a description of what happened and, '
            'if you can, a screenshot — it helps us fix things faster.',
      ),
      InfoSection(
        'Sales & plans',
        'Want to compare plans, add seats, or talk about Enterprise features '
            'like SSO and audit logging? Email sales@socialhub.example and we\'ll '
            'help you find the right fit.',
      ),
      InfoSection(
        'Partnerships & press',
        'For partnership ideas, integrations, or press enquiries, reach us at '
            'partnerships@socialhub.example. We\'re always open to working with '
            'people building in the same space.',
      ),
      InfoSection(
        'When to expect a reply',
        '',
        bullets: [
          'General enquiries — within two business days.',
          'Support — usually within one business day, and faster on paid plans.',
          'Security reports — we acknowledge these promptly; see the Security '
              'page for how to report a vulnerability.',
        ],
      ),
    ],
  ),
  'security': InfoPage(
    title: 'Security',
    intro: 'How SocialHub protects your data and the social accounts you '
        'connect to it.',
    sections: [
      InfoSection(
        'Your connected accounts',
        'You connect each social platform through its own secure OAuth flow, so '
            'you never give SocialHub your platform password. We request only the '
            'permissions needed to list the pages or profiles you manage and to '
            'publish the posts you schedule. The access tokens we receive are '
            'encrypted before they are stored, are never exposed through our API, '
            'and can be revoked at any time by disconnecting the account in '
            'Settings.',
      ),
      InfoSection(
        'Encryption',
        'All traffic between your browser and SocialHub is protected with TLS in '
            'transit, and sensitive data — including platform access tokens — is '
            'encrypted at rest.',
      ),
      InfoSection(
        'Protecting your account',
        'Your SocialHub login is guarded by multiple layers:',
        bullets: [
          'Email verification when you sign up, and a secure, time-limited '
              'password-reset flow.',
          'Optional two-factor authentication (TOTP) from any authenticator app.',
          'Rate limiting on sign-in to blunt brute-force and credential-stuffing '
              'attempts.',
          'Hardened HTTP security headers on every response.',
        ],
      ),
      InfoSection(
        'Access control',
        'Every organization has role-based access — owner, admin, editor, and '
            'viewer — and sensitive actions are restricted to the appropriate '
            'roles, so a viewer can\'t publish and an editor can\'t change '
            'billing. Enterprise plans add single sign-on (SSO) and audit '
            'logging.',
      ),
      InfoSection(
        'Safe publishing',
        'Publishing is treated as irreversible: SocialHub never blindly retries '
            'after an ambiguous failure, because a retry could double-post to a '
            'real, public account. If something goes wrong we surface the '
            'platform\'s own error so you can decide what to do next.',
      ),
      InfoSection(
        'Privacy & data deletion',
        'Disconnecting a platform deletes the stored token and account for it. '
            'For Meta platforms (Facebook, Instagram, Threads), removing SocialHub '
            'from the app\'s settings triggers Meta\'s deauthorize and '
            'data-deletion callbacks, and we delete the associated data '
            'automatically. See the Privacy Policy for the full detail and how to '
            'request deletion of everything.',
      ),
      InfoSection(
        'Reporting a vulnerability',
        'Found a security issue? Please tell us — responsible disclosure keeps '
            'everyone safer. Email security@socialhub.example with:',
        bullets: [
          'A clear description of the issue and where you found it.',
          'Steps to reproduce it, and the impact you think it has.',
          'Only ever test against your own account and data — never anyone '
              'else\'s.',
        ],
      ),
    ],
  ),
  'help': InfoPage(
    title: 'Help / Support',
    intro: 'Answers and step-by-step guidance for getting the most out of '
        'SocialHub.',
    sections: [
      InfoSection(
        'Getting started',
        'A first post takes just a few steps:',
        bullets: [
          'Create your account — a workspace is set up for you automatically.',
          'Connect your social platforms under Settings.',
          'Design your first post in Content, or upload an image or video.',
          'Schedule it, or publish it right away, and track it on the Calendar.',
        ],
      ),
      InfoSection(
        'Connecting your accounts',
        'Open Settings and connect Instagram, Threads, Facebook, X, or LinkedIn '
            'through each platform\'s secure sign-in. If a connection ever '
            'expires, you\'ll be prompted to reconnect — nothing is published '
            'until a valid connection is in place.',
      ),
      InfoSection(
        'Creating content',
        'Start a new design in Content, or use the Upload button to turn an '
            'image or video straight into a design. Speed things up with a saved '
            'template or one from the community marketplace, then edit text, '
            'images, and shapes on the canvas.',
      ),
      InfoSection(
        'Publishing & carousels',
        'In the editor, Export your design and use "Generate variants" to render '
            'it for each platform, then Publish — you can send it to several '
            'accounts at once. To post multiple images together, build a carousel '
            'from your media library (a single image is fine too).',
      ),
      InfoSection(
        'Scheduling',
        'Turn on "Schedule for later" to pick a date and time instead of '
            'publishing now. Everything you schedule appears on the Calendar, '
            'where you can review, reschedule, or cancel a post before it goes '
            'out.',
      ),
      InfoSection(
        'Using the AI assistant',
        'From the Publish dialog you can generate a caption, add hashtags, '
            'rewrite the tone, and check a post\'s viral score before it goes '
            'live. AI usage is subject to your plan\'s quota, which resets on a '
            'regular cycle.',
      ),
      InfoSection(
        'Analytics',
        'Analytics appear after your first published post. Metrics are pulled '
            'automatically from each connected platform about once an hour, so '
            'give it a little time after publishing for the first numbers to show '
            'up.',
      ),
      InfoSection(
        'Team & approvals',
        'Invite teammates and assign roles (owner, admin, editor, viewer). '
            'Editors can submit a design for approval, admins and owners can '
            'approve or reject it, and everyone can leave comments on a design to '
            'keep feedback in one place.',
      ),
      InfoSection(
        'Billing & plans',
        'Manage your subscription, payment method, and invoices under Billing in '
            'Settings. Upgrading unlocks more team seats, a larger AI quota, and '
            'Enterprise features such as SSO and audit logging.',
      ),
      InfoSection(
        'Frequently asked',
        '',
        bullets: [
          'Why is Analytics empty? — You need a connected account and at least '
              'one published post; the numbers arrive on the next hourly pull.',
          'Why can\'t I publish a design? — Export it and Generate variants '
              'first, and make sure you\'ve connected an account on that platform.',
          'Can I publish to several accounts at once? — Yes, select multiple '
              'accounts in the Publish dialog.',
          'Can a carousel have just one image? — Yes; a single image is '
              'published as a normal post.',
        ],
      ),
      InfoSection(
        'Still need a hand?',
        'If you can\'t find the answer here, email support@socialhub.example and '
            'we\'ll get you sorted.',
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
