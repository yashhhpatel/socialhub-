import { IsNotEmpty, IsString } from 'class-validator';

/** Body for enable/disable — a TOTP code (or a recovery code, for disable). */
export class MfaCodeDto {
  @IsString()
  @IsNotEmpty({ message: 'A verification code is required.' })
  code: string;
}

/** Body for the login second step: the challenge token plus a code. */
export class MfaVerifyDto {
  @IsString()
  @IsNotEmpty({ message: 'The MFA session token is required.' })
  challengeToken: string;

  @IsString()
  @IsNotEmpty({ message: 'A verification code is required.' })
  code: string;
}
