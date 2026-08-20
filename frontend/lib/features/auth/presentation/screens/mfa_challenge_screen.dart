import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../state/auth_controller.dart';
import '../state/auth_state.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/auth_text_field.dart';

/// Second step of an MFA login (Phase 17.3): the user enters the 6-digit code
/// from their authenticator (or a recovery code). The pending challenge token
/// lives in AuthController state — if it's absent (a direct visit or a reload),
/// we bounce back to /login.
class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error =
        await ref.read(authControllerProvider.notifier).verifyMfa(
              _codeController.text.trim(),
            );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } else {
      // Verified — tokens are now stored; head to the authenticated app.
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there's no pending challenge (reload / direct nav), go back to login.
    final status = ref.watch(
      authControllerProvider.select((s) => s.status),
    );
    if (status != AuthStatus.mfaRequired && status != AuthStatus.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && status == AuthStatus.unauthenticated) {
          context.go('/login');
        }
      });
    }

    return AuthScaffold(
      title: 'Two-factor authentication',
      subtitle: 'Enter the 6-digit code from your authenticator app.',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) AuthErrorBanner(message: _errorMessage!),
            AuthTextField(
              controller: _codeController,
              label: 'Authentication code',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your authentication or recovery code.';
                }
                return null;
              },
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              'Lost your device? Enter one of your recovery codes instead.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SpacingTokens.lg),
            AuthSubmitButton(
              label: 'Verify',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: SpacingTokens.sm),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      ref.read(authControllerProvider.notifier).cancelMfa();
                      context.go('/login');
                    },
              child: const Text('Back to log in'),
            ),
          ],
        ),
      ),
    );
  }
}
