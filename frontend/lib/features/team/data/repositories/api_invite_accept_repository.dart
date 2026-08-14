import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

/// The invitee's side of the flow (Milestone 11.3): a logged-out person
/// accepting an invite by setting their password. The endpoint is public —
/// the token in the URL is the authorization.
class ApiInviteAcceptRepository {
  ApiInviteAcceptRepository(this._dio);

  final Dio _dio;

  /// Accepts the invite, creating the account. The email/role/org all come
  /// from the invite the token resolves to, server-side.
  Future<void> accept(String token, String password) async {
    await _dio.post<void>('/invites/$token/accept', data: {'password': password});
  }
}

final inviteAcceptRepositoryProvider = Provider<ApiInviteAcceptRepository>((ref) {
  return ApiInviteAcceptRepository(ref.watch(apiClientProvider));
});
