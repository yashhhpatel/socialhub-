import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/social_account.dart';
import '../../domain/entities/social_platform.dart';
import '../../domain/repositories/social_accounts_repository.dart';

class ApiSocialAccountsRepository implements SocialAccountsRepository {
  ApiSocialAccountsRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<SocialAccount>> list() async {
    final response = await _dio.get<List<dynamic>>('/social-accounts');
    return (response.data ?? [])
        .map((e) => SocialAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> getConnectUrl(SocialPlatform platform) async {
    if (!platform.isConnectable) {
      // Defensive — the screen shouldn't offer a Connect button for
      // these at all (see SocialPlatform.isConnectable), so reaching
      // this is a bug elsewhere, not an expected user-facing path.
      throw StateError(
        '${platform.label} does not have a backend connect route yet.',
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/social-accounts/${platform.apiValue}/connect',
    );
    return response.data!['redirectUrl'] as String;
  }

  @override
  Future<void> disconnect(String accountId) async {
    await _dio.delete<void>('/social-accounts/$accountId');
  }
}

final socialAccountsRepositoryProvider = Provider<SocialAccountsRepository>((ref) {
  return ApiSocialAccountsRepository(ref.watch(apiClientProvider));
});
