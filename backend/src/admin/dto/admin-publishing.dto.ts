/// A publish job row in the admin view (Phase 21.7).
export class AdminPublishJobDto {
  id: string;
  orgId: string;
  orgName: string;
  platform: string;
  externalAccountId: string;
  status: string;
  attemptCount: number;
  lastError: string | null;
  scheduledAt: Date | null;
  externalPostId: string | null;
  createdAt: Date;
}

export class AdminPublishJobListDto {
  data: AdminPublishJobDto[];
  total: number;
  page: number;
  limit: number;
}
