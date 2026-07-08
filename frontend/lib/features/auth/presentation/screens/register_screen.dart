import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../state/auth_controller.dart';
import '../state/auth_state.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _orgNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateOrgName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 2 || trimmed.length > 100) {
      return 'Organization name must be 2–100 characters.';
    }
    return null;
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

    await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text,
          password: _passwordController.text,
          orgName: _orgNameController.text,
        );

    if (!mounted) return;

    final state = ref.read(authControllerProvider);
    if (state.status == AuthStatus.authenticated) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create your SocialHub account',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpacingTokens.xl),
                  if (authState.status == AuthStatus.error)
                    AuthErrorBanner(message: authState.errorMessage!),
                  AuthTextField(
                    controller: _orgNameController,
                    label: 'Organization name',
                    validator: _validateOrgName,
                  ),
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
                  const SizedBox(height: SpacingTokens.md),
                  TextButton(
                    onPressed: isLoading ? null : () => context.go('/login'),
                    child: const Text('Already have an account? Log in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
