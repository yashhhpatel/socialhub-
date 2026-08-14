import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_team_repository.dart';

/// Opens the invite dialog. Returns true if an invite was sent, so the caller
/// can refresh the pending list.
Future<bool?> showInviteModal(BuildContext context, String orgId) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _InviteModal(orgId: orgId),
  );
}

class _InviteModal extends ConsumerStatefulWidget {
  const _InviteModal({required this.orgId});

  final String orgId;

  @override
  ConsumerState<_InviteModal> createState() => _InviteModalState();
}

class _InviteModalState extends ConsumerState<_InviteModal> {
  final _emailController = TextEditingController();
  // Never owner — the owner seat isn't handed out via invite (backend rejects
  // it too). Editor is the sensible default seat for a new teammate.
  AppRole _role = AppRole.editor;
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _emailLooksValid {
    final v = _emailController.text.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  Future<void> _send() async {
    if (!_emailLooksValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }
    setState(() => _sending = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(teamRepositoryProvider)
          .invite(widget.orgId, _emailController.text.trim(), _role);
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Invitation sent.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send invite: ${describeApiError(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite teammate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: SpacingTokens.md),
          DropdownButtonFormField<AppRole>(
            value: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: AppRole.viewer, child: Text('Viewer — read only')),
              DropdownMenuItem(
                value: AppRole.editor,
                child: Text('Editor — create & publish'),
              ),
              DropdownMenuItem(
                value: AppRole.admin,
                child: Text('Admin — manage team & settings'),
              ),
            ],
            onChanged: (r) => setState(() => _role = r ?? AppRole.editor),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send invite'),
        ),
      ],
    );
  }
}
