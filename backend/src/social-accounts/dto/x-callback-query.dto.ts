import { IsOptional, IsString } from 'class-validator';

export class XCallbackQueryDto {
  @IsOptional()
  @IsString()
  code?: string;

  @IsOptional()
  @IsString()
  state?: string;

  // Present instead of `code` if the user denied the authorization
  // request — X redirects here with this instead.
  @IsOptional()
  @IsString()
  error?: string;
}
