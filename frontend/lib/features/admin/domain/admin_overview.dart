/// One plan tier's org count.
class PlanCount {
  const PlanCount({required this.tier, required this.count});
  final String tier;
  final int count;

  factory PlanCount.fromJson(Map<String, dynamic> json) => PlanCount(
        tier: json['tier'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// Cross-tenant platform KPIs for the admin Overview (Phase 21.2).
class AdminOverview {
  const AdminOverview({
    required this.totalOrganizations,
    required this.totalUsers,
    required this.newOrganizations30d,
    required this.newUsers30d,
    required this.activeOrganizations,
    required this.planDistribution,
    required this.connectedAccounts,
    required this.accountsNeedingReconnect,
    required this.publishedPosts,
    required this.failedPosts,
    required this.publishFailureRate,
    required this.unverifiedUsers,
    required this.mfaEnabledUsers,
  });

  final int totalOrganizations;
  final int totalUsers;
  final int newOrganizations30d;
  final int newUsers30d;
  final int activeOrganizations;
  final List<PlanCount> planDistribution;
  final int connectedAccounts;
  final int accountsNeedingReconnect;
  final int publishedPosts;
  final int failedPosts;
  final double publishFailureRate;
  final int unverifiedUsers;
  final int mfaEnabledUsers;

  int get failureRatePercent => (publishFailureRate * 100).round();

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    int i(String k) => (json[k] as num?)?.toInt() ?? 0;
    return AdminOverview(
      totalOrganizations: i('totalOrganizations'),
      totalUsers: i('totalUsers'),
      newOrganizations30d: i('newOrganizations30d'),
      newUsers30d: i('newUsers30d'),
      activeOrganizations: i('activeOrganizations'),
      planDistribution: (json['planDistribution'] as List<dynamic>? ?? [])
          .map((e) => PlanCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      connectedAccounts: i('connectedAccounts'),
      accountsNeedingReconnect: i('accountsNeedingReconnect'),
      publishedPosts: i('publishedPosts'),
      failedPosts: i('failedPosts'),
      publishFailureRate:
          (json['publishFailureRate'] as num?)?.toDouble() ?? 0,
      unverifiedUsers: i('unverifiedUsers'),
      mfaEnabledUsers: i('mfaEnabledUsers'),
    );
  }
}
