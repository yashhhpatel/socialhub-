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
  /** Whether the user is a platform (super) admin — drives the /admin panel
   * gate on the client (Phase 21). Server access is enforced independently by
   * PlatformAdminGuard; this is for showing/hiding the admin entry point. */
  isPlatformAdmin: boolean;
  createdAt: Date;
}
