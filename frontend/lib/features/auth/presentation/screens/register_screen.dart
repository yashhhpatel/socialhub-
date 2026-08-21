import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/platform/external_redirect.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../state/auth_controller.dart';
import '../state/auth_state.dart';
import '../widgets/auth_divider.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(value.trim())) return 'Enter a valid email.';
    return null;
  }

  // Mirrors the backend's password rule (see
  // docs/api/SocialHub_REST_API_Design.md, POST /auth/register): min 8
  // chars, at least 1 number, at least 1 symbol.
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // No manual navigation on success — see login_screen.dart's _submit()
    // for why: the route guard is the single source of truth for where
    // an authenticated user lands.
    await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  // Hand off to the backend's server-side Google flow: this navigates the whole
  // tab to /auth/google/start, which redirects to Google and back. The browser
  // never handles Google's tokens (see GoogleAuthService).
  void _continueWithGoogle() {
    redirectToExternal('$apiBaseUrl/auth/google/start');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Start managing every channel from one calm place.',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (authState.status == AuthStatus.error)
              AuthErrorBanner(message: authState.errorMessage!),
            GoogleSignInButton(
              onPressed: isLoading ? null : _continueWithGoogle,
            ),
            const SizedBox(height: SpacingTokens.md),
            const AuthDivider(label: 'or continue with email'),
            const SizedBox(height: SpacingTokens.md),
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
            ),
            const SizedBox(height: SpacingTokens.md),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: _validatePassword,
            ),
            const SizedBox(height: SpacingTokens.lg),
            AuthSubmitButton(
              label: 'Sign up',
              isLoading: isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: SpacingTokens.sm),
            TextButton(
              onPressed: isLoading ? null : () => context.go('/login'),
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
