import 'package:flutter/material.dart';

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

  IconData get _icon => switch (platform) {
        SocialPlatform.instagram => Icons.camera_alt_outlined,
        SocialPlatform.facebook => Icons.facebook,
        SocialPlatform.threads => Icons.tag,
        SocialPlatform.x => Icons.alternate_email,
        SocialPlatform.linkedin => Icons.business_center_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = account != null;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: colorScheme.primary),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(platform.label, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? 'Connected · ${account!.externalAccountId}'
                      : platform.isConnectable
                          ? 'Not connected'
                          : 'Coming soon',
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnected
                        ? Colors.greenAccent.shade400
                        : colorScheme.onSurface.withOpacity(0.55),
                    fontWeight: isConnected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _buildAction(context, isConnected),
        ],
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
        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
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
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text('Connect'),
    );
  }
}
