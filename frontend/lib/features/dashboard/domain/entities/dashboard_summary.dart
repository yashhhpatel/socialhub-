/// Shape of the dashboard's summary data. Domain layer (pure Dart), backed by
/// the real `GET /dashboard/summary` endpoint via ApiDashboardRepository.
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

  /// Plan's monthly AI allowance; -1 means unlimited (enterprise).
  final int aiCreditsTotal;
  final List<ActivityItem> recentActivity;

  /// True when the plan grants unlimited AI credits (no finite denominator).
  bool get aiCreditsUnlimited => aiCreditsTotal < 0;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final activity = (json['recentActivity'] as List<dynamic>? ?? [])
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return DashboardSummary(
      scheduledPosts: (json['scheduledPosts'] as num?)?.toInt() ?? 0,
      publishedPosts: (json['publishedPosts'] as num?)?.toInt() ?? 0,
      drafts: (json['drafts'] as num?)?.toInt() ?? 0,
      connectedAccounts: (json['connectedAccounts'] as num?)?.toInt() ?? 0,
      aiCreditsUsed: (json['aiCreditsUsed'] as num?)?.toInt() ?? 0,
      aiCreditsTotal: (json['aiCreditsTotal'] as num?)?.toInt() ?? 0,
      recentActivity: activity,
    );
  }
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

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      description: json['description'] as String? ?? '',
      timeAgo: json['timeAgo'] as String? ?? '',
      icon: json['icon'] as String? ?? 'default',
    );
  }
}
