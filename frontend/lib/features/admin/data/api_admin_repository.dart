import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_token_store.dart';
import '../domain/admin_organization.dart';
import '../domain/admin_overview.dart';
import '../domain/admin_social_account.dart';
import '../domain/admin_user.dart';

/// Talks to the platform-admin API (`/admin/*`, Phase 21). Every call is gated
/// server-side by PlatformAdminGuard; the client also hides the panel from
/// non-admins, but the server is the real boundary.
class ApiAdminRepository {
  ApiAdminRepository(this._dio);

  final Dio _dio;

  /// Confirms the caller is a platform admin; returns the admin's email.
  /// Throws (401/403) otherwise.
  Future<String> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/me');
    return response.data!['email'] as String;
  }

  /// Cross-tenant platform KPIs for the Overview dashboard (21.2).
  Future<AdminOverview> overview() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/overview');
    return AdminOverview.fromJson(response.data!);
  }

  /// Paginated, searchable organization list (21.3).
  Future<AdminOrgList> organizations({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/organizations',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'limit': limit,
      },
    );
    return AdminOrgList.fromJson(response.data!);
  }

  /// One organization's full detail (21.3).
  Future<AdminOrgDetail> organization(String id) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/admin/organizations/$id');
    return AdminOrgDetail.fromJson(response.data!);
  }

  /// Paginated, searchable user list (21.4).
  Future<AdminUserList> users({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/users',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'limit': limit,
      },
    );
    return AdminUserList.fromJson(response.data!);
  }

  /// One user's detail (21.4).
  Future<AdminUserDetail> user(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/users/$id');
    return AdminUserDetail.fromJson(response.data!);
  }

  Future<void> resendVerification(String id) =>
      _dio.post<void>('/admin/users/$id/resend-verification');

  Future<void> forcePasswordReset(String id) =>
      _dio.post<void>('/admin/users/$id/force-password-reset');

  /// Social-account health list (21.5), optionally filtered by status.
  Future<AdminSocialAccountList> socialAccounts({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/social-accounts',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    return AdminSocialAccountList.fromJson(response.data!);
  }

  /// Force a token refresh; returns the resulting status.
  Future<String> refreshSocialAccount(String id) async {
    final response = await _dio
        .post<Map<String, dynamic>>('/admin/social-accounts/$id/refresh');
    return response.data!['status'] as String? ?? 'unknown';
  }

  Future<void> disconnectSocialAccount(String id) =>
      _dio.post<void>('/admin/social-accounts/$id/disconnect');
}

final adminRepositoryProvider = Provider<ApiAdminRepository>((ref) {
  return ApiAdminRepository(ref.watch(apiClientProvider));
});

/// Server-verified admin check backing the panel. Re-evaluates on login/logout.
final adminMeProvider = FutureProvider.autoDispose<String>((ref) async {
  ref.watch(authTokenStoreProvider.select((t) => t != null));
  return ref.watch(adminRepositoryProvider).me();
});

/// Cross-tenant platform KPIs for the Overview dashboard (21.2).
final adminOverviewProvider =
    FutureProvider.autoDispose<AdminOverview>((ref) async {
  ref.watch(authTokenStoreProvider.select((t) => t != null));
  return ref.watch(adminRepositoryProvider).overview();
});

/// Query for the organizations list (search + page).
typedef AdminOrgQuery = ({String search, int page});

/// Organizations list (21.3), keyed by search + page.
final adminOrganizationsProvider = FutureProvider.autoDispose
    .family<AdminOrgList, AdminOrgQuery>((ref, query) async {
  return ref
      .watch(adminRepositoryProvider)
      .organizations(search: query.search, page: query.page);
});

/// One organization's detail (21.3), keyed by id.
final adminOrganizationProvider = FutureProvider.autoDispose
    .family<AdminOrgDetail, String>((ref, id) async {
  return ref.watch(adminRepositoryProvider).organization(id);
});

/// Query for the users list (search + page).
typedef AdminUserQuery = ({String search, int page});

/// Users list (21.4), keyed by search + page.
final adminUsersProvider = FutureProvider.autoDispose
    .family<AdminUserList, AdminUserQuery>((ref, query) async {
  return ref
      .watch(adminRepositoryProvider)
      .users(search: query.search, page: query.page);
});

/// One user's detail (21.4), keyed by id.
final adminUserProvider = FutureProvider.autoDispose
    .family<AdminUserDetail, String>((ref, id) async {
  return ref.watch(adminRepositoryProvider).user(id);
});

/// Social-account health list (21.5), keyed by status filter ('' = all).
final adminSocialAccountsProvider = FutureProvider.autoDispose
    .family<AdminSocialAccountList, String>((ref, status) async {
  return ref.watch(adminRepositoryProvider).socialAccounts(status: status);
});
