import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/analytics_overview.dart';

/// Reads the analytics dashboard data (Milestone 10.4). Uses the REST
/// fallback (GET /analytics/overview) rather than the GraphQL endpoint —
/// the whole app already speaks REST through Dio, so this avoids pulling a
/// GraphQL client into the frontend for one screen. The two share a backend
/// query service, so the numbers are identical either way.
class ApiAnalyticsRepository {
  ApiAnalyticsRepository(this._dio);

  final Dio _dio;

  Future<AnalyticsOverview> getOverview() async {
    final response = await _dio.get<Map<String, dynamic>>('/analytics/overview');
    return AnalyticsOverview.fromJson(response.data!);
  }
}

final analyticsRepositoryProvider = Provider<ApiAnalyticsRepository>((ref) {
  return ApiAnalyticsRepository(ref.watch(apiClientProvider));
});
