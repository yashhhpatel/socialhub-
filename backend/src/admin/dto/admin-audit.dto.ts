/// One audit-log entry in the admin cross-org view (Phase 21.8).
export class AdminAuditRowDto {
  id: string;
  orgId: string;
  actorEmail: string;
  method: string;
  path: string;
  targetId: string | null;
  statusCode: number;
  createdAt: Date;
}

export class AdminAuditListDto {
  data: AdminAuditRowDto[];
  total: number;
  page: number;
  limit: number;
}
