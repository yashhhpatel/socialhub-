import { IsNotEmpty, IsString, Matches, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @IsString()
  @IsNotEmpty({ message: 'A reset token is required.' })
  token: string;

  // Same strength rules as registration (RegisterDto) — a reset must not be a
  // way to set a weaker password than signup allows.
  @MinLength(8, { message: 'Password must be at least 8 characters.' })
  @Matches(/\d/, { message: 'Password must contain at least one number.' })
  @Matches(/[!@#$%^&*(),.?":{}|<>_\-+=]/, {
    message: 'Password must contain at least one symbol.',
  })
  newPassword: string;
}
