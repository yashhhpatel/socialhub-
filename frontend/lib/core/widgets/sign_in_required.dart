import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens/spacing_tokens.dart';

/// A friendly, on-brand stand-in shown where a page section needs an account
/// (its data 401s while signed out). Used in place of a raw error so every
/// page stays visible and explorable logged out, with a clear path to log in
/// — only the account-specific data waits behind sign-in.
class SignInRequired extends StatelessWidget {
  const SignInRequired({
    super.key,
    this.message = 'Log in to view this.',
    this.minHeight = 220,
  });

  final String message;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(SpacingTokens.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: SpacingTokens.md),
              Text(
                'Sign in to continue',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.xs),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.md),
              FilledButton(
                onPressed: () {
                  // Remember where we are so login can bring the user back
                  // here afterwards.
                  final from = GoRouterState.of(context).uri.toString();
                  context.go('/login?from=${Uri.encodeComponent(from)}');
                },
                child: const Text('Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
