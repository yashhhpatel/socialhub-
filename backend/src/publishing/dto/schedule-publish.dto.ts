import { IsISO8601, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

// The longest caption any supported platform accepts (Instagram's 2200).
// Same bound and reasoning as PublishNowDto.
const MAX_CAPTION_LENGTH = 2200;

/** Mirrors docs/SocialHub_REST_API_Design.md, POST /publish/schedule. */
export class SchedulePublishDto {
  @IsUUID()
  variantId: string;

  @IsUUID()
  socialAccountId: string;

  /**
   * When to publish, as an ISO-8601 timestamp. Validated as a well-formed
   * instant here; that it is actually in the FUTURE is enforced in the
   * service, where "now" is evaluated at request time.
   */
  @IsISO8601()
  scheduledAt: string;

  @IsOptional()
  @IsString()
  @MaxLength(MAX_CAPTION_LENGTH)
  caption?: string;
}
