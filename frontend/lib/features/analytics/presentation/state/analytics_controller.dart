import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../data/demo_analytics.dart';
import '../../data/repositories/api_analytics_repository.dart';
import '../../domain/entities/analytics_overview.dart';

/// The org's analytics overview (Milestone 10.4). Fetched on demand and
/// refreshed by invalidation — the underlying metrics only change when the
/// hourly ingestion pull runs, so there's nothing to stream.
final analyticsOverviewProvider = FutureProvider.autoDispose<AnalyticsOverview>(
  (ref) async {
    if (ref.watch(demoModeProvider)) return demoAnalyticsOverview();
    return ref.watch(analyticsRepositoryProvider).getOverview();
  },
);
