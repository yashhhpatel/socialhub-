import 'package:flutter/material.dart';

import '../../theme/tokens/spacing_tokens.dart';
import 'notifications_icon.dart';
import 'user_profile_menu.dart';

class NavTopBar extends StatelessWidget implements PreferredSizeWidget {
  const NavTopBar({
    super.key,
    required this.title,
    required this.userEmail,
    required this.userRole,
    required this.onLogout,
    required this.onOpenSettings,
    this.leading,
  });

  final String title;
  final String userEmail;
  final String userRole;
  final VoidCallback onLogout;
  final VoidCallback onOpenSettings;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: false,
      titleSpacing: leading == null ? SpacingTokens.lg : 0,
      title: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      actions: [
        const NotificationsIcon(),
        const SizedBox(width: SpacingTokens.sm),
        UserProfileMenu(
          email: userEmail,
          role: userRole,
          onLogout: onLogout,
          onOpenSettings: onOpenSettings,
        ),
        const SizedBox(width: SpacingTokens.lg),
      ],
    );
  }
}
