import { IsOptional, IsString, MaxLength } from 'class-validator';

/** Query for GET /templates/marketplace (Milestone 14.1). */
export class SearchMarketplaceDto {
  /** Case-insensitive substring match on the template name. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  category?: string;
}
