import { SetMetadata } from '@nestjs/common';
import { UserRole } from '@prisma/client';

export const ROLES_KEY = 'roles';

/**
 * Marks a route with the MINIMUM role required to access it, matching the
 * "owner > admin > editor > viewer" hierarchy and the "admin+"/"editor+"
 * shorthand used throughout docs/api/SocialHub_REST_API_Design.md.
 *
 * Deliberately a single minimum role, not an arbitrary role list — every
 * permission rule in this project is expressed as a rank threshold (e.g.
 * "admin+"), never as an unordered set of allowed roles, so the decorator
 * mirrors that exactly rather than being more general than anything we
 * actually need.
 *
 * Usage (from a future milestone, once real endpoints need it):
 *   @Roles(UserRole.admin)
 *   @UseGuards(JwtAuthGuard, RolesGuard)
 *   @Patch(':id')
 *   someAdminOnlyRoute() { ... }
 *
 * Not applied to any route yet in this milestone — see RolesGuard for why.
 */
export const Roles = (minimumRole: UserRole) =>
  SetMetadata(ROLES_KEY, minimumRole);
