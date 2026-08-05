import { IsUUID } from 'class-validator';

/** Mirrors docs/SocialHub_REST_API_Design.md, POST /publish/now. */
export class PublishNowDto {
  @IsUUID()
  variantId: string;

  @IsUUID()
  socialAccountId: string;
}
