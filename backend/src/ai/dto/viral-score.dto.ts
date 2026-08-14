import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

/** POST /ai/viral-score (Milestone 12.2). */
export class ViralScoreDto {
  @IsUUID()
  assetId: string;

  /** The caption the user plans to post with — factored into the estimate. */
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  caption?: string;
}

export class ViralScoreResponseDto {
  score: number;
  rationale: string;
}
