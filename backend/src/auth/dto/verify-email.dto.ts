import { IsNotEmpty, IsString } from 'class-validator';

export class VerifyEmailDto {
  @IsString()
  @IsNotEmpty({ message: 'A verification token is required.' })
  token: string;
}
