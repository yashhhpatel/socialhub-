import { IsString, MinLength } from 'class-validator';

/// Body for POST /auth/google/exchange: the single-use handoff ticket minted
/// by the Google callback, swapped here for a real session.
export class GoogleExchangeDto {
  @IsString()
  @MinLength(1, { message: 'A login ticket is required.' })
  ticket: string;
}
