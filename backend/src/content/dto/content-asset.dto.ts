import { ApprovalStatus, ContentAssetType } from '@prisma/client';

import { ContentVariantDto } from './content-variant.dto';

export class ContentAssetDto {
  id: string;
  orgId: string;
  createdById: string;
  type: ContentAssetType;
  canvasJson: unknown;
  /** Flattened render of canvasJson, uploaded by the editor (4.1). */
  masterImageUrl: string | null;
  masterImagePublicId: string | null;
  approvalStatus: ApprovalStatus;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * What GET /content/assets/:id returns — the asset plus its per-platform
 * variants, per docs/SocialHub_REST_API_Design.md ("full asset including
 * nested `variants` summary"). Clients poll this after the 202 from
 * POST /content/assets/:id/variants to watch generation complete.
 */
export class ContentAssetDetailDto extends ContentAssetDto {
  variants: ContentVariantDto[];
}
