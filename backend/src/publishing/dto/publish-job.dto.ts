import { PublishJobStatus } from '@prisma/client';

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
