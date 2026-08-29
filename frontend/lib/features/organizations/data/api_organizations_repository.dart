import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// The signed-in user's org overview (GET /organizations/me).
class OrgOverview {
  const OrgOverview({
    required this.id,
    required this.name,
    required this.planTier,
    required this.requiresApproval,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String planTier;
  final bool requiresApproval;
  final int memberCount;

  factory OrgOverview.fromJson(Map<String, dynamic> json) => OrgOverview(
        id: json['id'] as String,
        name: json['name'] as String,
        planTier: json['planTier'] as String,
        requiresApproval: json['requiresApproval'] as bool? ?? false,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      );
}

class ApiOrganizationsRepository {
  ApiOrganizationsRepository(this._dio);

  final Dio _dio;

  Future<OrgOverview> getOverview() async {
    final response = await _dio.get<Map<String, dynamic>>('/organizations/me');
    return OrgOverview.fromJson(response.data!);
  }
}

final organizationsRepositoryProvider =
    Provider<ApiOrganizationsRepository>((ref) {
  return ApiOrganizationsRepository(ref.watch(apiClientProvider));
});

final orgOverviewProvider =
    FutureProvider.autoDispose<OrgOverview>((ref) async {
  return ref.watch(organizationsRepositoryProvider).getOverview();
});
