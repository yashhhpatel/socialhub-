import { ApprovalStatus, ContentAssetType } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';

/**
 * Query params for GET /content/assets, per
 * docs/SocialHub_REST_API_Design.md (`?page=&limit=&type=&approvalStatus=`).
 *
 * `Type(() => Number)` is required because query params arrive as
 * strings — without it @IsInt rejects even a valid `?page=2`.
 */
export class ListContentAssetsDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  // Capped so a client can't ask for the whole table in one request and
  // turn a list view into an accidental denial of service.
  @Max(100)
  limit?: number = 20;

  @IsOptional()
  @IsEnum(ContentAssetType)
  type?: ContentAssetType;

  @IsOptional()
  @IsEnum(ApprovalStatus)
  approvalStatus?: ApprovalStatus;
}

/** Standard pagination envelope shared by every list endpoint (§0). */
export class PaginationMetaDto {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export class PaginatedDto<T> {
  data: T[];
  meta: PaginationMetaDto;
}
