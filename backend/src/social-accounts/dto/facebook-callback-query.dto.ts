import { IsOptional, IsString } from 'class-validator';

export class FacebookCallbackQueryDto {
  @IsOptional()
  @IsString()
  code?: string;

  @IsOptional()
  @IsString()
  state?: string;

  // Present instead of `code` if the user denied the authorization
  // request — Facebook redirects here with this instead.
  @IsOptional()
  @IsString()
  error?: string;
}
