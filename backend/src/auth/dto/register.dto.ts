import { IsEmail, Matches, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail({}, { message: 'Enter a valid email address.' })
  email: string;

  // Mirrors docs/api/SocialHub_REST_API_Design.md, POST /auth/register:
  // min 8 chars, at least 1 number, at least 1 symbol.
  @MinLength(8, { message: 'Password must be at least 8 characters.' })
  @Matches(/\d/, { message: 'Password must contain at least one number.' })
  @Matches(/[!@#$%^&*(),.?":{}|<>_\-+=]/, {
    message: 'Password must contain at least one symbol.',
  })
  password: string;

  // Organization name is no longer collected at signup. Every new account
  // gets a default workspace auto-created from the user's email (renameable
  // later in settings) — see AuthService.register / defaultOrgName.
}
