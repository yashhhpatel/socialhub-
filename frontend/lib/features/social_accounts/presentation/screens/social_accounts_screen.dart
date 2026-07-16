import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../domain/entities/social_account.dart';
import '../../domain/entities/social_platform.dart';
import '../state/social_accounts_controller.dart';
import '../widgets/platform_connection_card.dart';

/// Reachable at /settings (see core/router/app_router.dart). Becomes the
/// first real section of a proper multi-section settings page once one
/// exists — see that router file's comment on why the original
/// features/settings/ placeholder is currently unreferenced rather than
/// deleted.
///
/// `queryParams` carries the OAuth callback's result when the backend
/// redirects the browser back here (see
/// backend/src/social-accounts/social-accounts.controller.ts's
/// respondToCallback) — e.g. `?connected=instagram` or
/// `?connectError=...`.
class SocialAccountsScreen extends ConsumerStatefulWidget {
  const SocialAccountsScreen({super.key, this.queryParams = const {}});

  final Map<String, String> queryParams;

  @override
  ConsumerState<SocialAccountsScreen> createState() => _SocialAccountsScreenState();
}

class _SocialAccountsScreenState extends ConsumerState<SocialAccountsScreen> {
  SocialPlatform? _connectingPlatform;
  String? _disconnectingAccountId;

  @override
  void initState() {
    super.initState();
    // Runs once, after the first frame, so ScaffoldMessenger is
    // available and this doesn't fire again on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallbackResult());
  }

  void _handleCallbackResult() {
    final connected = widget.queryParams['connected'];
    final error = widget.queryParams['connectError'];

    if (connected != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$connected connected successfully.')),
      );
      // The list was already fetched once at controller construction,
      // before this OAuth round trip completed — refresh to pick up the
      // newly connected account.
      ref.read(socialAccountsControllerProvider.notifier).refresh();
    } else if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _handleConnect(SocialPlatform platform) async {
    setState(() => _connectingPlatform = platform);
    try {
      // connect() navigates the browser away on success — this only
      // returns (via the catch) if it threw before that happened.
      await ref.read(socialAccountsControllerProvider.notifier).connect(platform);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start connecting ${platform.label}: $e')),
      );
      setState(() => _connectingPlatform = null);
    }
  }

  Future<void> _handleDisconnect(SocialAccount account) async {
    setState(() => _disconnectingAccountId = account.id);
    try {
      await ref.read(socialAccountsControllerProvider.notifier).disconnect(account.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not disconnect ${account.platform.label}: $e')),
      );
    } finally {
      if (mounted) setState(() => _disconnectingAccountId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(socialAccountsControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connected Accounts', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Connect your social platforms to publish content directly from SocialHub.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          accountsState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorState(
              message: '$error',
              onRetry: () => ref.read(socialAccountsControllerProvider.notifier).refresh(),
            ),
            data: (accounts) => Column(
              children: [
                for (final platform in SocialPlatform.values) ...[
                  PlatformConnectionCard(
                    platform: platform,
                    account: _accountFor(accounts, platform),
                    isConnecting: _connectingPlatform == platform,
                    isDisconnecting: _disconnectingAccountId ==
                        _accountFor(accounts, platform)?.id,
                    onConnect: () => _handleConnect(platform),
                    onDisconnect: () {
                      final account = _accountFor(accounts, platform);
                      if (account != null) _handleDisconnect(account);
                    },
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  SocialAccount? _accountFor(List<SocialAccount> accounts, SocialPlatform platform) {
    for (final account in accounts) {
      if (account.platform == platform) return account;
    }
    return null;
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Could not load connected accounts: $message'),
        const SizedBox(height: SpacingTokens.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
