/// A row in the admin users list (Phase 21.4). No secrets — sign-in method is
/// derived server-side from credential presence, never the values.
export class AdminUserListItemDto {
  id: string;
  email: string;
  role: string;
  orgId: string;
  orgName: string;
  emailVerified: boolean;
  mfaEnabled: boolean;
  isPlatformAdmin: boolean;
  hasPassword: boolean;
  hasGoogle: boolean;
  createdAt: Date;
}

export class AdminUserListDto {
  data: AdminUserListItemDto[];
  total: number;
  page: number;
  limit: number;
}

export class AdminUserDetailDto extends AdminUserListItemDto {
  orgPlanTier: string;
  updatedAt: Date;
}
