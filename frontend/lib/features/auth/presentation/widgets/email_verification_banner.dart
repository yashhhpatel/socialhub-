import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_account_repository.dart';
import '../state/current_user_provider.dart';

/// Persistent nudge shown across the app while a signed-in user hasn't
/// confirmed their email (Phase 17.1). Renders nothing when signed out, while
/// the profile is still loading, or once the email is verified — so it never
/// flashes spuriously. Offers a one-tap resend.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _sending = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    final result =
        await ref.read(accountRepositoryProvider).resendVerification();
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ?? (result.ok ? 'Verification email sent.' : 'Failed to send.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only meaningful when signed in.
    if (ref.watch(authTokenStoreProvider) == null) {
      return const SizedBox.shrink();
    }

    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    // Hide while loading/errored, or once verified — never guess.
    if (user == null || user.emailVerified) return const SizedBox.shrink();

    final theme = Theme.of(context);
    const amber = Color(0xFF92400E);
    const amberBg = Color(0xFFFEF3C7);

    return Material(
      color: amberBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.lg,
          vertical: SpacingTokens.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined, color: amber, size: 20),
            const SizedBox(width: SpacingTokens.sm),
            Expanded(
              child: Text(
                'Please verify your email (${user.email}) to secure your account.',
                style: theme.textTheme.bodyMedium?.copyWith(color: amber),
              ),
            ),
            const SizedBox(width: SpacingTokens.sm),
            TextButton(
              onPressed: _sending ? null : _resend,
              style: TextButton.styleFrom(foregroundColor: amber),
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resend'),
            ),
          ],
        ),
      ),
    );
  }
}
