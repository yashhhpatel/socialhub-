import { Platform, SocialAccountStatus } from '@prisma/client';

/**
 * Never includes accessTokenEnc/refreshTokenEnc — not even encrypted
 * ciphertext should leave the API, regardless of how well-protected it
 * is at rest. The controller maps the full Prisma SocialAccount down to
 * this shape explicitly (see social-accounts.controller.ts), rather than
 * relying on callers to remember not to serialize the whole row.
 */
export class SocialAccountSummaryDto {
  id: string;
  platform: Platform;
  externalAccountId: string;
  status: SocialAccountStatus;
  expiresAt: Date | null;
  createdAt: Date;
}
