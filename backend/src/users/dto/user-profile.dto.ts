import { UserRole } from '@prisma/client';

export class UserProfileDto {
  id: string;
  email: string;
  role: UserRole;
  orgId: string;
  /** Whether the user has confirmed their email (Phase 17.1). */
  emailVerified: boolean;
  /** Whether TOTP multi-factor auth is enabled (Phase 17.3). */
  mfaEnabled: boolean;
  createdAt: Date;
}
