import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_account_repository.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_notice_banner.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/auth_text_field.dart';

/// Sets a new password from an emailed reset link. The token arrives in the
/// URL (`/reset-password?token=...`); the user only supplies the new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Mirrors the backend rules (ResetPasswordDto): min 8, a number, a symbol.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must contain at least one number.';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=]').hasMatch(value)) {
      return 'Password must contain at least one symbol.';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(accountRepositoryProvider).resetPassword(
          token: widget.token!,
          newPassword: _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.ok) {
        _successMessage = result.message;
      } else {
        _errorMessage = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // A link with no token is unusable — say so plainly rather than showing a
    // form that can only fail on submit.
    if (widget.token == null || widget.token!.isEmpty) {
      return AuthScaffold(
        title: 'Reset your password',
        subtitle: 'This reset link is invalid.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthErrorBanner(
              message:
                  'This password reset link is missing its token. Request a '
                  'new link and try again.',
            ),
            TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: const Text('Request a new link'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Enter a new password for your account.',
      child: _successMessage != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthNoticeBanner(message: _successMessage!),
                const SizedBox(height: SpacingTokens.sm),
                AuthSubmitButton(
                  label: 'Log in',
                  isLoading: false,
                  onPressed: () => context.go('/login'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    AuthErrorBanner(message: _errorMessage!),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'New password',
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  AuthTextField(
                    controller: _confirmController,
                    label: 'Confirm new password',
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: _validateConfirm,
                  ),
                  const SizedBox(height: SpacingTokens.lg),
                  AuthSubmitButton(
                    label: 'Reset password',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}
