/// Shape of the dashboard's summary data. Domain layer, so it has no idea
/// whether it's backed by mock data (now) or a real analytics endpoint
/// (Phase 10) — swapping the data source later changes only
/// data/dashboard_mock_data.dart, never this entity or the screen.
class DashboardSummary {
  const DashboardSummary({
    required this.scheduledPosts,
    required this.publishedPosts,
    required this.drafts,
    required this.connectedAccounts,
    required this.aiCreditsUsed,
    required this.aiCreditsTotal,
    required this.recentActivity,
  });

  final int scheduledPosts;
  final int publishedPosts;
  final int drafts;
  final int connectedAccounts;
  final int aiCreditsUsed;
  final int aiCreditsTotal;
  final List<ActivityItem> recentActivity;
}

class ActivityItem {
  const ActivityItem({
    required this.description,
    required this.timeAgo,
    required this.icon,
  });

  final String description;
  final String timeAgo;

  /// Kept as a small string tag rather than a Flutter IconData here —
  /// domain entities shouldn't depend on Flutter itself (per Clean
  /// Architecture: domain is pure Dart). The presentation widget maps
  /// this tag to a real icon.
  final String icon;
}
