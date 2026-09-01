import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../../auth/presentation/state/current_user_provider.dart';
import '../../data/demo_team.dart';
import '../../data/repositories/api_team_repository.dart';
import '../../domain/entities/team_member.dart';

/// The org's members (Milestone 11.3). Depends on currentUser for the orgId,
/// so it only fires once the user is known. Signed out: a sample roster.
final teamMembersProvider = FutureProvider.autoDispose<List<TeamMember>>((ref) async {
  if (ref.watch(demoModeProvider)) return demoTeamMembers;
  final user = await ref.watch(currentUserProvider.future);
  return ref.watch(teamRepositoryProvider).listMembers(user.orgId);
});

/// The org's pending invites. Signed out: sample pending invites.
final teamInvitesProvider = FutureProvider.autoDispose<List<TeamInvite>>((ref) async {
  if (ref.watch(demoModeProvider)) return demoTeamInvites;
  final user = await ref.watch(currentUserProvider.future);
  return ref.watch(teamRepositoryProvider).listInvites(user.orgId);
});
