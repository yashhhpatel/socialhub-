import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/dashboard_summary.dart';
import 'demo_dashboard.dart';

/// Talks to the real dashboard endpoint (`GET /dashboard/summary`), org-scoped
/// server-side. No mock/fallback data — the screen surfaces loading/error
/// states from the live call.
class ApiDashboardRepository {
  ApiDashboardRepository(this._dio);

  final Dio _dio;

  Future<DashboardSummary> getSummary() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/dashboard/summary');
    return DashboardSummary.fromJson(response.data!);
  }
}

final dashboardRepositoryProvider = Provider<ApiDashboardRepository>((ref) {
  return ApiDashboardRepository(ref.watch(apiClientProvider));
});

/// The Overview dashboard's data. autoDispose so it re-fetches when the user
/// returns to the page; re-evaluates on login/logout via the token store.
final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  // Signed out: serve the explorable demo overview; signed in: live data.
  if (ref.watch(demoModeProvider)) return demoDashboardSummary;
  return ref.watch(dashboardRepositoryProvider).getSummary();
});
