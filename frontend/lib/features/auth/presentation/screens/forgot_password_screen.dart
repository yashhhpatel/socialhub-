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

/// "Forgot your password?" — collects an email and asks the backend to send a
/// reset link. The backend never reveals whether the email is registered, so
/// on success we show a deliberately generic confirmation and hide the form.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(value.trim())) return 'Enter a valid email.';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(accountRepositoryProvider)
        .requestPasswordReset(_emailController.text.trim());

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
    return AuthScaffold(
      title: 'Reset your password',
      subtitle: "Enter your email and we'll send you a reset link.",
      child: _successMessage != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthNoticeBanner(message: _successMessage!),
                const SizedBox(height: SpacingTokens.sm),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to log in'),
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
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: SpacingTokens.lg),
                  AuthSubmitButton(
                    label: 'Send reset link',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => context.go('/login'),
                    child: const Text('Back to log in'),
                  ),
                ],
              ),
            ),
    );
  }
}
