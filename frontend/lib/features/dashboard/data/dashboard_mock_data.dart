import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/dashboard_summary.dart';

/// Realistic placeholder data, per explicit request: "build the complete
/// production-ready UI structure first with realistic placeholder data."
///
/// Replaced by a real repository once there's something to fetch from —
/// scheduled/published/draft counts come from Phase 4's ContentVariant/
/// PublishJob tables, connected-account count from Phase 2's
/// SocialAccount table, AI credits from Phase 5's AiUsageLog, recent
/// activity from Phase 15's AuditLog. Until those exist, this provider
/// is the entire "data layer" for the dashboard — swapping it for a real
/// one later changes only this file, since the screen depends on
/// dashboardSummaryProvider's shape (DashboardSummary), not on how it's
/// produced.
final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  return const DashboardSummary(
    scheduledPosts: 12,
    publishedPosts: 148,
    drafts: 5,
    connectedAccounts: 3,
    aiCreditsUsed: 240,
    aiCreditsTotal: 500,
    recentActivity: [
      ActivityItem(
        description: 'Instagram post "Summer Sale" published',
        timeAgo: '2h ago',
        icon: 'published',
      ),
      ActivityItem(
        description: 'X account reconnected',
        timeAgo: '5h ago',
        icon: 'account',
      ),
      ActivityItem(
        description: 'Draft "Product launch teaser" saved',
        timeAgo: '1d ago',
        icon: 'draft',
      ),
      ActivityItem(
        description: 'LinkedIn post scheduled for tomorrow',
        timeAgo: '1d ago',
        icon: 'scheduled',
      ),
      ActivityItem(
        description: 'AI caption generated for "Fall Collection"',
        timeAgo: '2d ago',
        icon: 'ai',
      ),
    ],
  );
});
