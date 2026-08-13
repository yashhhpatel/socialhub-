import { Platform, PublishJobStatus } from '@prisma/client';

/** Response for POST /publish/now — `{ jobId, status }` per the REST doc. */
export class PublishNowResponseDto {
  jobId: string;
  status: PublishJobStatus;
}

/** Response for GET /publish/jobs/:id. */
export class PublishJobDto {
  id: string;
  status: PublishJobStatus;
  attemptCount: number;
  scheduledAt: Date | null;
  lastError: string | null;
  externalPostId: string | null;
}

/**
 * A row in GET /publish/jobs — carries the platform so the scheduler view
 * (Milestone 7.4) can group and label without a second lookup.
 */
export class PublishJobSummaryDto {
  id: string;
  platform: Platform;
  status: PublishJobStatus;
  scheduledAt: Date | null;
  attemptCount: number;
  lastError: string | null;
  externalPostId: string | null;
  createdAt: Date;
}
