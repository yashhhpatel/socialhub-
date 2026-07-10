import { IsEmail, Length, Matches, MinLength } from 'class-validator';

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

  // Deferred from Milestone 1.1 (Organization didn't exist yet). Mirrors
  // the REST API design doc's rule: 2–100 chars.
  @Length(2, 100, { message: 'Organization name must be 2–100 characters.' })
  orgName: string;
}
