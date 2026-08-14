import { UserRole } from '@prisma/client';
import { IsEmail, IsEnum } from 'class-validator';

/**
 * Invite a teammate (Milestone 11.1). `role` is the seat they'll get; the
 * service caps it to the inviter's own rank (you can't invite someone above
 * yourself) and forbids inviting another owner.
 */
export class CreateInviteDto {
  @IsEmail()
  email: string;

  @IsEnum(UserRole)
  role: UserRole;
}
