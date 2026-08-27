import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsISO8601,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

// The longest caption any supported platform accepts (Instagram's 2200).
const MAX_CAPTION_LENGTH = 2200;

// A generous upper bound so the request is well-formed; the exact per-platform
// ceiling (Instagram 10, X 4, …) is enforced in the service against the target
// account's adapter capabilities.
const MAX_CAROUSEL_ITEMS = 20;

/**
 * POST /publish/carousel — publish (or, with `scheduledAt`, schedule) an
 * ordered set of media-library image URLs as one native carousel/album post.
 */
export class PublishCarouselDto {
  @IsString()
  socialAccountId: string;

  /** Ordered, publicly-reachable image URLs. Array order is the slide order. */
  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(MAX_CAROUSEL_ITEMS)
  @IsString({ each: true })
  mediaUrls: string[];

  @IsOptional()
  @IsString()
  @MaxLength(MAX_CAPTION_LENGTH)
  caption?: string;

  /**
   * When present, schedules the carousel for this future ISO-8601 time instead
   * of publishing immediately (mirrors POST /publish/schedule).
   */
  @IsOptional()
  @IsISO8601()
  scheduledAt?: string;
}
