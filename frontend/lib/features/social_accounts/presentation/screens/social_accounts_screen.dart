import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/motion/skeleton.dart';
import '../../../../core/motion/staggered_item.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../auth/presentation/widgets/danger_zone_card.dart';
import '../../../auth/presentation/widgets/mfa_settings_card.dart';
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
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
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
        SnackBar(
          content: Text(
            'Could not connect ${platform.label}: ${describeApiError(e)}',
          ),
        ),
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
        SnackBar(
          content: Text(
            'Could not disconnect ${account.platform.label}: ${describeApiError(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _disconnectingAccountId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(socialAccountsControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Manage how SocialHub looks and the accounts it publishes to.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          Text('Security', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SpacingTokens.md),
          const MfaSettingsCard(),
          const SizedBox(height: SpacingTokens.lg),
          Text('Connected accounts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Connect your social platforms to publish content directly from SocialHub.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
          ),
          const SizedBox(height: SpacingTokens.md),
          accountsState.when(
            loading: () => Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
                    child: Skeleton(
                      height: 72,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
              ],
            ),
            // Logged out (unauthorized) still shows the full platform list —
            // every card reads "Not connected", and tapping Connect routes to
            // login (the connect call 401s → login redirect). Only a real
            // error shows a retry state.
            error: (error, _) => isUnauthorized(error)
                ? _buildPlatformList(const [])
                : _ErrorState(
                    message: describeApiError(error),
                    onRetry: () =>
                        ref.read(socialAccountsControllerProvider.notifier).refresh(),
                  ),
            data: _buildPlatformList,
          ),
          const SizedBox(height: SpacingTokens.lg),
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SpacingTokens.md),
          const DangerZoneCard(),
        ],
      ),
    );
  }

  /// The list of platform cards, driven by whatever accounts are connected
  /// (empty when logged out — every card then reads "Not connected"). Kept as
  /// one builder so the signed-in and logged-out views share the exact same UI.
  Widget _buildPlatformList(List<SocialAccount> accounts) {
    return Column(
      children: [
        for (var i = 0; i < SocialPlatform.values.length; i++) ...[
          StaggeredItem(
            index: i,
            child: PlatformConnectionCard(
              platform: SocialPlatform.values[i],
              account: _accountFor(accounts, SocialPlatform.values[i]),
              isConnecting: _connectingPlatform == SocialPlatform.values[i],
              isDisconnecting: _disconnectingAccountId ==
                  _accountFor(accounts, SocialPlatform.values[i])?.id,
              onConnect: () => _handleConnect(SocialPlatform.values[i]),
              onDisconnect: () {
                final account = _accountFor(accounts, SocialPlatform.values[i]);
                if (account != null) _handleDisconnect(account);
              },
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
        ],
      ],
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
