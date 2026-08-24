import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_user.dart';

/// Admin → User detail (Phase 21.4): profile + safe actions (resend
/// verification, force password reset). The admin never sees/sets a password.
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(okMessage)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: ${describeApiError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(adminUserProvider(widget.userId));
    final repo = ref.read(adminRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/admin/users'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Users'),
          ),
          const SizedBox(height: SpacingTokens.sm),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              describeApiError(error),
              style: theme.textTheme.bodyMedium,
            ),
            data: (u) => _Detail(
              user: u,
              busy: _busy,
              onResendVerification: () => _run(
                () => repo.resendVerification(u.id),
                'Verification email sent.',
              ),
              onForceReset: () => _run(
                () => repo.forcePasswordReset(u.id),
                'Password-reset link sent.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.user,
    required this.busy,
    required this.onResendVerification,
    required this.onForceReset,
  });

  final AdminUserDetail user;
  final bool busy;
  final VoidCallback onResendVerification;
  final VoidCallback onForceReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(user.email, style: theme.textTheme.headlineMedium),
        const SizedBox(height: SpacingTokens.xs),
        Wrap(
          spacing: SpacingTokens.sm,
          runSpacing: SpacingTokens.sm,
          children: [
            Chip(label: Text('Role: ${user.role}')),
            Chip(label: Text('Sign-in: ${user.signInMethod}')),
            Chip(
              label: Text(user.emailVerified ? 'Email verified' : 'Unverified'),
            ),
            Chip(label: Text(user.mfaEnabled ? 'MFA on' : 'MFA off')),
            if (user.isPlatformAdmin) const Chip(label: Text('Platform admin')),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SpacingTokens.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Organization', '${user.orgName}  ·  ${user.orgPlanTier}'),
              _row('User id', user.id),
              _row(
                'Created',
                user.createdAt?.toIso8601String().split('T').first ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.lg),
        Text('Actions', style: theme.textTheme.titleMedium),
        const SizedBox(height: SpacingTokens.sm),
        Wrap(
          spacing: SpacingTokens.sm,
          runSpacing: SpacingTokens.sm,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : onResendVerification,
              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
              label: const Text('Resend verification'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onForceReset,
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('Force password reset'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
