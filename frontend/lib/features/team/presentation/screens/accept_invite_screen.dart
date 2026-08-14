import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_invite_accept_repository.dart';

/// Public accept-invite page (Milestone 11.3) — where the invite email link
/// lands (`/accept-invite?token=...`). The invitee sets a password; on
/// success they're sent to /login to sign in with the account just created.
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final token = widget.token;
    if (token == null || token.isEmpty) return;
    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(inviteAcceptRepositoryProvider).accept(token, _passwordController.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('Account created — please sign in.')),
      );
      router.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not accept invite: ${describeApiError(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasToken = widget.token != null && widget.token!.isNotEmpty;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Accept invitation', style: theme.textTheme.headlineSmall),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  hasToken
                      ? 'Set a password to join your team on SocialHub.'
                      : 'This invite link is missing its token. Ask for a new invitation.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (hasToken) ...[
                  const SizedBox(height: SpacingTokens.lg),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Choose a password'),
                    onSubmitted: (_) => _accept(),
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  FilledButton(
                    onPressed: _submitting ? null : _accept,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept & create account'),
                  ),
                ],
                const SizedBox(height: SpacingTokens.md),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
