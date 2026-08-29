import 'package:flutter/material.dart';

import '../../../../core/motion/tap_scale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/platform_style.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../domain/entities/social_account.dart';
import '../../domain/entities/social_platform.dart';

class PlatformConnectionCard extends StatelessWidget {
  const PlatformConnectionCard({
    super.key,
    required this.platform,
    required this.account,
    required this.isConnecting,
    required this.isDisconnecting,
    required this.onConnect,
    required this.onDisconnect,
  });

  final SocialPlatform platform;

  /// null if this platform has no connected account for the current org.
  final SocialAccount? account;

  final bool isConnecting;
  final bool isDisconnecting;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = account != null;
    final brand = PlatformStyle.color(platform.apiValue, colorScheme);

    return TapScale(
      hoverElevation: true,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.md),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: brand.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                PlatformStyle.icon(platform.apiValue),
                color: brand,
              ),
            ),
            const SizedBox(width: SpacingTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusPill(
                        connected: isConnected,
                        connectable: platform.isConnectable,
                      ),
                      if (isConnected) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            account!.externalAccountId,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.55),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _buildAction(context, isConnected),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context, bool isConnected) {
    if (!platform.isConnectable) {
      return const Chip(label: Text('Coming soon'));
    }

    if (isConnected) {
      return OutlinedButton(
        onPressed: isDisconnecting ? null : onDisconnect,
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
        child: isDisconnecting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Disconnect'),
      );
    }

    return ElevatedButton(
      onPressed: isConnecting ? null : onConnect,
      child: isConnecting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textPrimary,
              ),
            )
          : const Text('Connect'),
    );
  }
}

/// Small colored pill summarising a platform's connection status.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected, required this.connectable});

  final bool connected;
  final bool connectable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color color, String label) = connected
        ? (AppColors.success, 'Connected')
        : connectable
            ? (scheme.onSurfaceVariant, 'Not connected')
            : (AppColors.warning, 'Coming soon');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
