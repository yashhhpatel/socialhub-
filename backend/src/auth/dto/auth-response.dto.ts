import { UserRole } from '@prisma/client';

/**
 * role/orgId are now included — deferred here from Milestone 1.1's commit,
 * which documented exactly this: "role/orgId depend on Organization,
 * which doesn't exist until Milestone 1.2... will gain those fields in
 * that milestone's commit, not before." This is that commit.
 */
export class AuthUserDto {
  id: string;
  email: string;
  role: UserRole;
  orgId: string;
}

export class AuthResponseDto {
  user: AuthUserDto;
  accessToken: string;
  refreshToken: string;
}
