import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

/**
 * The longest caption any supported platform accepts (Instagram's 2200 —
 * see instagram.adapter.ts's capabilities()). A per-platform check is not
 * done here: the DTO does not know which platform the variant targets, and
 * the platform itself rejects an over-length caption with a message far
 * more useful than anything guessed at this layer. This bound exists only
 * to stop an unbounded string reaching the database and the provider.
 */
const MAX_CAPTION_LENGTH = 2200;

/** Mirrors docs/SocialHub_REST_API_Design.md, POST /publish/now. */
export class PublishNowDto {
  @IsUUID()
  variantId: string;

  @IsUUID()
  socialAccountId: string;

  /**
   * Caption to post with (Milestone 5.3).
   *
   * Optional, and it OVERRIDES the variant's stored caption rather than
   * replacing it: the caption a user just generated and edited in the
   * publish modal belongs to this publish attempt. Persisting it back onto
   * the variant is a separate concern with its own endpoint, and nothing
   * writes ContentVariant.caption yet — so without this field, a generated
   * caption had no route to the post at all.
   */
  @IsOptional()
  @IsString()
  @MaxLength(MAX_CAPTION_LENGTH)
  caption?: string;
}
