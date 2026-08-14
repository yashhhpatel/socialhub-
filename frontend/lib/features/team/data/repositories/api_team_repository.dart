import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/team_member.dart';

/// Talks to the team-management endpoints (Milestone 11.3). All are scoped
/// to [orgId] in the path (the backend also verifies it matches the token's
/// org). These endpoints are admin+ on the backend, so the screen only calls
/// them once it knows the current user is an admin.
class ApiTeamRepository {
  ApiTeamRepository(this._dio);

  final Dio _dio;

  Future<List<TeamMember>> listMembers(String orgId) async {
    final response = await _dio.get<List<dynamic>>('/organizations/$orgId/members');
    return (response.data ?? [])
        .map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> changeRole(String orgId, String userId, AppRole role) async {
    await _dio.patch<void>(
      '/organizations/$orgId/members/$userId/role',
      data: {'role': role.apiValue},
    );
  }

  Future<List<TeamInvite>> listInvites(String orgId) async {
    final response = await _dio.get<List<dynamic>>('/organizations/$orgId/invites');
    return (response.data ?? [])
        .map((i) => TeamInvite.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<void> invite(String orgId, String email, AppRole role) async {
    await _dio.post<void>(
      '/organizations/$orgId/invite',
      data: {'email': email, 'role': role.apiValue},
    );
  }

  Future<void> revokeInvite(String orgId, String inviteId) async {
    await _dio.delete<void>('/organizations/$orgId/invites/$inviteId');
  }
}

final teamRepositoryProvider = Provider<ApiTeamRepository>((ref) {
  return ApiTeamRepository(ref.watch(apiClientProvider));
});
