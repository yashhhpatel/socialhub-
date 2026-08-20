import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_mfa_repository.dart';
import '../state/current_user_provider.dart';

/// Two-factor auth management in Settings (Phase 17.3): enroll (QR + code ->
/// recovery codes) or disable. Reads current state from currentUserProvider
/// and invalidates it after any change so the UI reflects the new state.
class MfaSettingsCard extends ConsumerWidget {
  const MfaSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                'Two-factor authentication',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Add a second step at login using an authenticator app.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          userAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text(
              'Sign in to manage two-factor authentication.',
              style: theme.textTheme.bodyMedium,
            ),
            data: (user) => user.mfaEnabled
                ? _EnabledRow(onDisable: () => _disableFlow(context, ref))
                : _DisabledRow(onEnable: () => _enableFlow(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _enableFlow(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(mfaRepositoryProvider);

    late final MfaSetup setup;
    try {
      setup = await repo.setup();
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not start setup. Try again.');
      return;
    }
    if (!context.mounted) return;

    final codes = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EnrollDialog(setup: setup, repo: repo),
    );

    if (codes != null) {
      ref.invalidate(currentUserProvider);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => _RecoveryCodesDialog(codes: codes),
        );
      }
    }
  }

  Future<void> _disableFlow(BuildContext context, WidgetRef ref) async {
    final disabled = await showDialog<bool>(
      context: context,
      builder: (_) => _DisableDialog(repo: ref.read(mfaRepositoryProvider)),
    );
    if (disabled == true) {
      ref.invalidate(currentUserProvider);
      if (context.mounted) _toast(context, 'Two-factor authentication disabled.');
    }
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EnabledRow extends StatelessWidget {
  const _EnabledRow({required this.onDisable});
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
        const SizedBox(width: SpacingTokens.sm),
        Expanded(
          child: Text('Enabled', style: theme.textTheme.bodyLarge),
        ),
        OutlinedButton(onPressed: onDisable, child: const Text('Disable')),
      ],
    );
  }
}

class _DisabledRow extends StatelessWidget {
  const _DisabledRow({required this.onEnable});
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: onEnable,
        icon: const Icon(Icons.lock_outline, size: 18),
        label: const Text('Enable two-factor authentication'),
      ),
    );
  }
}

/// Step 1 of enrollment: show the QR + secret, take a code, call enable().
class _EnrollDialog extends StatefulWidget {
  const _EnrollDialog({required this.setup, required this.repo});
  final MfaSetup setup;
  final ApiMfaRepository repo;

  @override
  State<_EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends State<_EnrollDialog> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the 6-digit code from your app.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final codes = await widget.repo.enable(code);
      if (mounted) Navigator.of(context).pop(codes);
    } on MfaException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Set up two-factor authentication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1. Scan this QR code with your authenticator app.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: SpacingTokens.md),
            Center(
              child: Container(
                padding: const EdgeInsets.all(SpacingTokens.sm),
                color: Colors.white,
                child: QrImageView(
                  data: widget.setup.otpauthUri,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.md),
            Text(
              "Or enter this key manually:",
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: SpacingTokens.xs),
            SelectableText(
              _grouped(widget.setup.secret),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1.2,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.setup.secret));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Key copied.')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy key'),
            ),
            const SizedBox(height: SpacingTokens.md),
            Text(
              '2. Enter the 6-digit code to confirm.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: SpacingTokens.sm),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Authentication code',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enable'),
        ),
      ],
    );
  }

  // Display the base32 secret in groups of 4 for legibility.
  String _grouped(String secret) {
    final buffer = StringBuffer();
    for (var i = 0; i < secret.length; i += 4) {
      if (i > 0) buffer.write(' ');
      buffer.write(secret.substring(i, (i + 4).clamp(0, secret.length)));
    }
    return buffer.toString();
  }
}

/// Step 2: show the one-time recovery codes (only chance to save them).
class _RecoveryCodesDialog extends StatelessWidget {
  const _RecoveryCodesDialog({required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Save your recovery codes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Store these somewhere safe. Each code works once if you lose '
              'access to your authenticator. They will not be shown again.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: SpacingTokens.md),
            Container(
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                codes.join('\n'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: codes.join('\n')));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recovery codes copied.')),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Confirm disable by requiring a current code.
class _DisableDialog extends StatefulWidget {
  const _DisableDialog({required this.repo});
  final ApiMfaRepository repo;

  @override
  State<_DisableDialog> createState() => _DisableDialogState();
}

class _DisableDialogState extends State<_DisableDialog> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a code to confirm.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repo.disable(code);
      if (mounted) Navigator.of(context).pop(true);
    } on MfaException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Disable two-factor authentication'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter a current authentication or recovery code to confirm.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: SpacingTokens.md),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Code',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Disable'),
        ),
      ],
    );
  }
}
