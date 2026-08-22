/// One row in the dashboard's recent-activity feed.
export class DashboardActivityItemDto {
  description: string;
  timeAgo: string;
  /// Icon tag the client maps to an IconData: published | scheduled | draft |
  /// account | ai.
  icon: string;
}

/// The Overview dashboard's summary, all org-scoped and derived from existing
/// models (GET /dashboard/summary).
export class DashboardSummaryDto {
  scheduledPosts: number;
  publishedPosts: number;
  drafts: number;
  connectedAccounts: number;
  aiCreditsUsed: number;
  /// Plan's monthly AI allowance; -1 means unlimited (enterprise).
  aiCreditsTotal: number;
  recentActivity: DashboardActivityItemDto[];
}
