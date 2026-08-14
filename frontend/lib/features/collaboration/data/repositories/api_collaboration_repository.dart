import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/approval_status.dart';
import '../../domain/entities/comment.dart';

/// Talks to the Phase 13 collaboration endpoints (Milestone 13.3): comment
/// threads and the approval workflow.
class ApiCollaborationRepository {
  ApiCollaborationRepository(this._dio);

  final Dio _dio;

  Future<List<Comment>> listComments(String assetId) async {
    final response = await _dio.get<List<dynamic>>('/content/assets/$assetId/comments');
    return [for (final c in (response.data ?? [])) Comment.fromJson(c as Map<String, dynamic>)];
  }

  Future<Comment> addComment(String assetId, String body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/content/assets/$assetId/comments',
      data: {'body': body},
    );
    return Comment.fromJson(response.data!);
  }

  /// Reads the asset's current approval status off the detail endpoint.
  Future<ApprovalStatus> approvalStatus(String assetId) async {
    final response = await _dio.get<Map<String, dynamic>>('/content/assets/$assetId');
    return ApprovalStatusX.fromApi(response.data!['approvalStatus'] as String);
  }

  Future<ApprovalStatus> changeApproval(String assetId, ApprovalStatus status) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/content/assets/$assetId/approval',
      data: {'status': status.apiValue},
    );
    return ApprovalStatusX.fromApi(response.data!['approvalStatus'] as String);
  }

  Future<bool> getPolicy() async {
    final response = await _dio.get<Map<String, dynamic>>('/content/approval-policy');
    return response.data!['requiresApproval'] as bool;
  }

  Future<bool> setPolicy(bool requiresApproval) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/content/approval-policy',
      data: {'requiresApproval': requiresApproval},
    );
    return response.data!['requiresApproval'] as bool;
  }
}

final collaborationRepositoryProvider = Provider<ApiCollaborationRepository>((ref) {
  return ApiCollaborationRepository(ref.watch(apiClientProvider));
});

/// The comment thread for an asset (Milestone 13.3).
final commentsProvider =
    FutureProvider.autoDispose.family<List<Comment>, String>((ref, assetId) async {
  return ref.watch(collaborationRepositoryProvider).listComments(assetId);
});

/// The asset's current approval status.
final approvalStatusProvider =
    FutureProvider.autoDispose.family<ApprovalStatus, String>((ref, assetId) async {
  return ref.watch(collaborationRepositoryProvider).approvalStatus(assetId);
});
