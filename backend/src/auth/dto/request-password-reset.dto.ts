import { IsEmail } from 'class-validator';

export class RequestPasswordResetDto {
  @IsEmail({}, { message: 'Enter a valid email address.' })
  email: string;
}
