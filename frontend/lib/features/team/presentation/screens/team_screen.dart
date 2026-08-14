import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/state/current_user_provider.dart';
import '../../data/repositories/api_team_repository.dart';
import '../../domain/entities/team_member.dart';
import '../state/team_controller.dart';
import '../widgets/invite_modal.dart';

/// Team management (Milestone 11.3). Admin+ only: the roster with per-member
/// role controls, pending invites, and an invite action. A non-admin sees a
/// clear access-denied state rather than a broken screen (the underlying
/// endpoints are admin+ and would 403 anyway) — this is the role-gated UI in
/// its most consequential place.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load your account: ${describeApiError(error)}')),
        data: (user) => user.isAdmin ? _TeamAdminView(user: user) : const _AccessDenied(),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

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
          Text(
            'Team management is available to admins and the owner.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TeamAdminView extends ConsumerWidget {
  const _TeamAdminView({required this.user});

  final CurrentUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final membersAsync = ref.watch(teamMembersProvider);
    final invitesAsync = ref.watch(teamInvitesProvider);

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Team', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: SpacingTokens.xs),
                  Text(
                    'Manage who can access this workspace.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openInvite(context, ref, user.orgId),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Invite teammate'),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        const _SectionHeader('Members'),
        membersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(SpacingTokens.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Could not load members: ${describeApiError(e)}'),
          data: (members) => Column(
            children: [
              for (final m in members)
                _MemberTile(member: m, currentUser: user),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.lg),
        const _SectionHeader('Pending invites'),
        invitesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Could not load invites: ${describeApiError(e)}'),
          data: (invites) => invites.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: SpacingTokens.sm),
                  child: Text('No pending invites.'),
                )
              : Column(
                  children: [
                    for (final inv in invites)
                      _InviteTile(invite: inv, orgId: user.orgId),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _openInvite(BuildContext context, WidgetRef ref, String orgId) async {
    final sent = await showInviteModal(context, orgId);
    if (sent == true) ref.invalidate(teamInvitesProvider);
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.currentUser});

  final TeamMember member;
  final CurrentUser currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSelf = member.id == currentUser.id;
    final isOwner = member.role == AppRole.owner;
    // The owner's role is fixed, and you can't change your own — matching the
    // backend's guards, so the control is disabled rather than failing on tap.
    final canEdit = !isOwner && !isSelf;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        leading: CircleAvatar(child: Text(member.email[0].toUpperCase())),
        title: Text(member.email),
        subtitle: isSelf ? const Text('You') : null,
        trailing: canEdit
            ? _RoleDropdown(
                value: member.role,
                onChanged: (role) => _change(context, ref, role),
              )
            : Chip(label: Text(member.role.label)),
      ),
    );
  }

  Future<void> _change(BuildContext context, WidgetRef ref, AppRole role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(teamRepositoryProvider).changeRole(currentUser.orgId, member.id, role);
      ref.invalidate(teamMembersProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('${member.email} is now ${role.label}.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not change role: ${describeApiError(error)}')),
      );
    }
  }
}

/// Role picker limited to assignable roles (never owner).
class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.value, required this.onChanged});

  final AppRole value;
  final ValueChanged<AppRole> onChanged;

  static const _assignable = [AppRole.viewer, AppRole.editor, AppRole.admin];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<AppRole>(
      value: _assignable.contains(value) ? value : null,
      hint: Text(value.label),
      items: [
        for (final r in _assignable)
          DropdownMenuItem(value: r, child: Text(r.label)),
      ],
      onChanged: (r) {
        if (r != null && r != value) onChanged(r);
      },
    );
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.invite, required this.orgId});

  final TeamInvite invite;
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: SpacingTokens.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        leading: const Icon(Icons.mail_outline),
        title: Text(invite.email),
        subtitle: Text('Invited as ${invite.role.label}'),
        trailing: TextButton(
          onPressed: () => _revoke(context, ref),
          child: const Text('Revoke'),
        ),
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(teamRepositoryProvider).revokeInvite(orgId, invite.id);
      ref.invalidate(teamInvitesProvider);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not revoke: ${describeApiError(error)}')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
