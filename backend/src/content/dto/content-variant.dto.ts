import { Platform, VariantStatus } from '@prisma/client';

export class ContentVariantDto {
  id: string;
  assetId: string;
  platform: Platform;
  renderedMediaUrl: string | null;
  caption: string | null;
  hashtags: string | null;
  status: VariantStatus;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Response envelope for POST /content/assets/:id/variants, matching the
 * `{ "variants": [...] }` shape documented in
 * docs/SocialHub_REST_API_Design.md.
 */
export class GenerateVariantsResponseDto {
  variants: ContentVariantDto[];
}
