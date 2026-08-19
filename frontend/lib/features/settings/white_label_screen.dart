import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error_message.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/widgets/sign_in_required.dart';
import '../auth/presentation/state/current_user_provider.dart';
import 'data/api_white_label_repository.dart';
import 'domain/white_label.dart';

/// White-label settings (Milestone 15.4): an admin sets the org's logo and
/// primary colour, which then brand the whole app shell for that org's users.
/// Admin+ only — a non-admin sees an access-denied state.
class WhiteLabelScreen extends ConsumerStatefulWidget {
  const WhiteLabelScreen({super.key});

  @override
  ConsumerState<WhiteLabelScreen> createState() => _WhiteLabelScreenState();
}

class _WhiteLabelScreenState extends ConsumerState<WhiteLabelScreen> {
  final _logoController = TextEditingController();
  final _colorController = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _logoController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _hydrate(WhiteLabel? wl) {
    if (_hydrated) return;
    _logoController.text = wl?.logoUrl ?? '';
    _colorController.text = wl?.primaryColorHex ?? '';
    _hydrated = true;
  }

  bool _validColor(String v) =>
      v.isEmpty || RegExp(r'^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(v);

  Future<void> _save(String orgId) async {
    final color = _colorController.text.trim();
    if (!_validColor(color)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid hex colour, e.g. #1A2B3C, or leave it blank.')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final logo = _logoController.text.trim();
      await ref.read(whiteLabelRepositoryProvider).update(
            orgId,
            // Empty field => clear (null); otherwise the value.
            logoUrl: logo.isEmpty ? null : logo,
            primaryColor: color.isEmpty ? null : color,
          );
      // Refresh the app-wide branding so the new theme applies immediately.
      ref.invalidate(whiteLabelProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Branding saved.')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save branding: ${describeApiError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => isUnauthorized(e)
            ? const SignInRequired(
                message: 'Log in as an admin to manage white-label branding.',
              )
            : Center(child: Text('Could not load your account: ${describeApiError(e)}')),
        data: (user) {
          if (!user.isAdmin) return const _AdminsOnly();
          final wlAsync = ref.watch(whiteLabelProvider);
          return wlAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load branding: ${describeApiError(e)}')),
            data: (wl) {
              _hydrate(wl);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('White label', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    'Apply your own logo and colour across the app for your team.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: SpacingTokens.lg),
                  TextField(
                    controller: _logoController,
                    decoration: const InputDecoration(
                      labelText: 'Logo image URL',
                      hintText: 'https://…/logo.png',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.md),
                  TextField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Primary colour (hex)',
                      hintText: '#1A2B3C',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}), // live preview
                  ),
                  const SizedBox(height: SpacingTokens.lg),
                  _Preview(
                    logoUrl: _logoController.text.trim(),
                    color: parseHexColor(_colorController.text.trim()),
                  ),
                  const SizedBox(height: SpacingTokens.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _save(user.orgId),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save branding'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.logoUrl, required this.color});

  final String logoUrl;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final swatch = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview', style: theme.textTheme.labelMedium),
          const SizedBox(height: SpacingTokens.sm),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: swatch,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: logoUrl.isNotEmpty
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, color: Colors.white),
                      )
                    : const Icon(Icons.image_outlined, color: Colors.white),
              ),
              const SizedBox(width: SpacingTokens.md),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(backgroundColor: swatch),
                child: const Text('Sample button'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminsOnly extends StatelessWidget {
  const _AdminsOnly();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: SpacingTokens.md),
          Text('Admins only', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text('Branding is managed by admins and the owner.', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
