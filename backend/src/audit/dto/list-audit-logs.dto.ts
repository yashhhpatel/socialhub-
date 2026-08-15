import { Type } from 'class-transformer';
import {
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

/** Query for GET /audit-logs (Milestone 15.2). */
export class ListAuditLogsDto {
  /** Filter by HTTP method (POST/PATCH/PUT/DELETE). */
  @IsOptional()
  @IsString()
  method?: string;

  /** Filter by the acting user's email (exact match). */
  @IsOptional()
  @IsString()
  actorEmail?: string;

  /** ISO-8601 lower/upper bounds on when the action happened. */
  @IsOptional()
  @IsISO8601()
  from?: string;

  @IsOptional()
  @IsISO8601()
  to?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  limit?: number;
}
