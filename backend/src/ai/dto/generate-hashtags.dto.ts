import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

/** POST /ai/hashtags (Milestone 12.1). */
export class GenerateHashtagsDto {
  @IsUUID()
  assetId: string;

  /** How many hashtags to return (default 10). Bounded so one request can't
   * ask the model for an unreasonable list. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(30)
  count?: number;
}

export class GenerateHashtagsResponseDto {
  hashtags: string[];
}
