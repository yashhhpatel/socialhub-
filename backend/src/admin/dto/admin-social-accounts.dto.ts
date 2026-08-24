/// A row in the admin social-accounts view (Phase 21.5). Token ciphertext is
/// never selected or returned.
export class AdminSocialAccountDto {
  id: string;
  orgId: string;
  orgName: string;
  platform: string;
  externalAccountId: string;
  status: string;
  expiresAt: Date | null;
  createdAt: Date;
}

export class AdminSocialAccountListDto {
  data: AdminSocialAccountDto[];
  total: number;
  page: number;
  limit: number;
}

/// Result of an admin-triggered token refresh.
export class AdminRefreshResultDto {
  id: string;
  status: string;
  needsReconnect: boolean;
}
