import { UserRole } from '@prisma/client';
import { IsEnum } from 'class-validator';

/** Sets a member's role (Milestone 11.2). The service enforces the rank and
 * owner rules; this just validates it's a real role value. */
export class ChangeRoleDto {
  @IsEnum(UserRole)
  role: UserRole;
}
