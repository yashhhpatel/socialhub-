import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_token_store.dart';
import '../domain/app_notification.dart';

/// Talks to the backend /notifications endpoints (Phase 19).
class ApiNotificationsRepository {
  ApiNotificationsRepository(this._dio);

  final Dio _dio;

  Future<List<AppNotification>> list({int limit = 30}) async {
    final response = await _dio.get<List<dynamic>>(
      '/notifications',
      queryParameters: {'limit': limit},
    );
    return (response.data ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
    return response.data!['count'] as int? ?? 0;
  }

  Future<void> markRead(String id) =>
      _dio.post<void>('/notifications/$id/read');

  Future<void> markAllRead() => _dio.post<void>('/notifications/read-all');

  /// Dismisses (permanently deletes) one of the caller's own notifications.
  Future<void> delete(String id) => _dio.delete<void>('/notifications/$id');
}

final notificationsRepositoryProvider =
    Provider<ApiNotificationsRepository>((ref) {
  return ApiNotificationsRepository(ref.watch(apiClientProvider));
});

/// Unread count for the bell badge. Re-evaluates on login/logout (watches token
/// presence, not value) and returns 0 when logged out rather than surfacing a
/// 401 — the bell just shows no badge.
final unreadNotificationsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final loggedIn = ref.watch(authTokenStoreProvider.select((t) => t != null));
  if (!loggedIn) return 0;
  try {
    return await ref.watch(notificationsRepositoryProvider).unreadCount();
  } catch (_) {
    return 0;
  }
});

/// The notifications list, fetched when the panel opens. autoDispose so it
/// re-fetches each time the bell is opened.
final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  ref.watch(authTokenStoreProvider.select((t) => t != null));
  return ref.watch(notificationsRepositoryProvider).list();
});
