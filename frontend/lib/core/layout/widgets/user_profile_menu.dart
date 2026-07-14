import 'package:flutter/material.dart';

/// Deliberately presentational-only: no Riverpod or go_router dependency
/// here at all. AppShell (the one place already acting as a composition
/// root — see its doc comment) reads the real session and wires
/// navigation, passing plain data and callbacks in. Keeping this widget
/// dependency-free means it's trivially reusable/testable without any
/// provider or router setup.
class UserProfileMenu extends StatelessWidget {
  const UserProfileMenu({
    super.key,
    required this.email,
    required this.role,
    required this.onLogout,
    required this.onOpenSettings,
  });

  final String email;
  final String role;
  final VoidCallback onLogout;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 44),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                role,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Log out'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'logout') onLogout();
        if (value == 'settings') onOpenSettings();
      },
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          email.isNotEmpty ? email[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
