import {
  ArrayMaxSize,
  IsArray,
  IsHexColor,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
} from 'class-validator';

/**
 * Partial update for the org's brand kit (Milestone 9.3). Every field is
 * optional so the editor can PATCH just what changed (e.g. only the logo)
 * without resending the whole kit. An omitted field is left untouched; a
 * field sent as an empty array clears it.
 */
export class UpdateBrandKitDto {
  /** Hex colours (e.g. `#1A2B3C`). Validated so a malformed value can't be
   * stored and then break a colour picker on read. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(24)
  @IsHexColor({ each: true })
  colors?: string[];

  /** Font-family names. Free text (a family this app can't render is the
   * user's choice to make), only length-bounded. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(24)
  @IsString({ each: true })
  @MaxLength(120, { each: true })
  fonts?: string[];

  /** Cloudinary URL of the uploaded logo, from POST /content/assets/upload. */
  @IsOptional()
  @IsUrl({ require_tld: false }, { message: 'logoUrl must be a valid URL.' })
  logoUrl?: string;

  @IsOptional()
  @IsString()
  logoPublicId?: string;
}
