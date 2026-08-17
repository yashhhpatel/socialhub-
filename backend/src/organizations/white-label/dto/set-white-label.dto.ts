import {
  IsHexColor,
  IsOptional,
  IsUrl,
  ValidateIf,
} from 'class-validator';

/**
 * PATCH /organizations/:orgId/white-label (Milestone 15.4). Each field is
 * optional; an explicit null clears it (reverts to default branding), so
 * both are `ValidateIf(!== null)` — null is allowed, a malformed value is not.
 */
export class SetWhiteLabelDto {
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsUrl({ require_tld: false }, { message: 'logoUrl must be a valid URL.' })
  logoUrl?: string | null;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsHexColor({ message: 'primaryColor must be a hex colour, e.g. #1A2B3C.' })
  primaryColor?: string | null;
}
