/// A Meta data-deletion request in the admin compliance queue (Phase 21.9).
export class AdminDataDeletionRowDto {
  id: string;
  platform: string;
  confirmationCode: string;
  status: string;
  createdAt: Date;
}

export class AdminDataDeletionListDto {
  data: AdminDataDeletionRowDto[];
  total: number;
  page: number;
  limit: number;
}

/// Result of a suspend/reactivate action.
export class AdminOrgStatusDto {
  orgId: string;
  status: string;
  suspendedAt: Date | null;
}
