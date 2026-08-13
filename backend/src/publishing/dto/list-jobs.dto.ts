import { PublishJobStatus } from '@prisma/client';
import { IsEnum, IsOptional } from 'class-validator';

/** Query for GET /publish/jobs (Milestone 7.4). */
export class ListJobsDto {
  /** Optional status filter, e.g. `?status=scheduled`. */
  @IsOptional()
  @IsEnum(PublishJobStatus)
  status?: PublishJobStatus;
}
