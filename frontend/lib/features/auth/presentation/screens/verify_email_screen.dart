import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_account_repository.dart';
import '../state/current_user_provider.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_notice_banner.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_submit_button.dart';

/// Lands from the verification email link (`/verify-email?token=...`) and
/// confirms the token immediately. Shows a spinner while verifying, then a
/// success or error state. On success it refreshes the cached current-user so
/// the "verify your email" banner disappears without a reload.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

enum _Status { verifying, success, error }

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  _Status _status = _Status.verifying;
  String _message = '';

  @override
  void initState() {
    super.initState();
    // Kick off verification after the first frame so provider reads are safe.
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = _Status.error;
        _message =
            'This verification link is missing its token. Try requesting a '
            'new one from your account.';
      });
      return;
    }

    final result = await ref.read(accountRepositoryProvider).verifyEmail(token);
    if (!mounted) return;

    if (result.ok) {
      // Refresh the profile so a signed-in user's banner clears immediately.
      if (ref.read(authTokenStoreProvider) != null) {
        ref.invalidate(currentUserProvider);
      }
      setState(() {
        _status = _Status.success;
        _message = result.message ?? 'Your email has been verified.';
      });
    } else {
      setState(() {
        _status = _Status.error;
        _message = result.message ?? 'Verification failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authTokenStoreProvider) != null;

    return AuthScaffold(
      title: 'Email verification',
      subtitle: switch (_status) {
        _Status.verifying => 'Confirming your email address…',
        _Status.success => 'You’re all set.',
        _Status.error => 'We couldn’t verify this link.',
      },
      child: switch (_status) {
        _Status.verifying => const Padding(
            padding: EdgeInsets.symmetric(vertical: SpacingTokens.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        _Status.success => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthNoticeBanner(message: _message),
              const SizedBox(height: SpacingTokens.sm),
              AuthSubmitButton(
                label: isAuthenticated ? 'Go to dashboard' : 'Log in',
                isLoading: false,
                onPressed: () =>
                    context.go(isAuthenticated ? '/dashboard' : '/login'),
              ),
            ],
          ),
        _Status.error => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthErrorBanner(message: _message),
              TextButton(
                onPressed: () =>
                    context.go(isAuthenticated ? '/dashboard' : '/login'),
                child: Text(isAuthenticated ? 'Back to dashboard' : 'Back to log in'),
              ),
            ],
          ),
      },
    );
  }
}
