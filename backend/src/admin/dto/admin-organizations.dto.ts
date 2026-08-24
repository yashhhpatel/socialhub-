/// A row in the admin organizations list (Phase 21.3).
export class AdminOrgListItemDto {
  id: string;
  name: string;
  planTier: string;
  subscriptionStatus: string | null;
  memberCount: number;
  socialAccountCount: number;
  createdAt: Date;
}

/// Paginated list envelope.
export class AdminOrgListDto {
  data: AdminOrgListItemDto[];
  total: number;
  page: number;
  limit: number;
}

/// One member in an org detail view — no secrets.
export class AdminOrgMemberDto {
  id: string;
  email: string;
  role: string;
  emailVerified: boolean;
  mfaEnabled: boolean;
  isPlatformAdmin: boolean;
}

/// Full org detail for the admin panel (Phase 21.3).
export class AdminOrgDetailDto {
  id: string;
  name: string;
  planTier: string;
  status: string;
  requiresApproval: boolean;
  subscriptionStatus: string | null;
  currentPeriodEnd: Date | null;
  createdAt: Date;
  members: AdminOrgMemberDto[];
  usage: {
    socialAccounts: number;
    teamMembers: number;
    aiCreditsUsed: number;
  };
  limits: {
    maxSocialAccounts: number;
    maxTeamMembers: number;
    aiCreditsPerMonth: number;
    maxScheduledPosts: number;
  };
  activity: {
    connectedAccounts: number;
    drafts: number;
    scheduledPosts: number;
    publishedPosts: number;
  };
}
