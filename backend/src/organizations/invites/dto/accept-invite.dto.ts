import { IsString, MinLength } from 'class-validator';

/**
 * Accept an invite (Milestone 11.1). The invitee sets their password here;
 * their email, role, and org all come from the invite the token resolves to,
 * never from the client.
 */
export class AcceptInviteDto {
  @IsString()
  @MinLength(8, { message: 'Password must be at least 8 characters.' })
  password: string;
}
