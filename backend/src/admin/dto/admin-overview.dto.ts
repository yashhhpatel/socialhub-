/// One plan tier's org count (Phase 21.2).
export class PlanCountDto {
  tier: string;
  count: number;
}

/// Cross-tenant platform KPIs for the admin Overview dashboard.
export class AdminOverviewDto {
  totalOrganizations: number;
  totalUsers: number;
  /// Signups in the trailing 30 days.
  newOrganizations30d: number;
  newUsers30d: number;
  /// Orgs with at least one connected social account (a proxy for "activated").
  activeOrganizations: number;
  planDistribution: PlanCountDto[];
  connectedAccounts: number;
  /// Social accounts not in `connected` state (expired/revoked/error).
  accountsNeedingReconnect: number;
  publishedPosts: number;
  failedPosts: number;
  /// failed / (published + failed), 0..1; 0 when there are no terminal jobs.
  publishFailureRate: number;
  unverifiedUsers: number;
  mfaEnabledUsers: number;
}
