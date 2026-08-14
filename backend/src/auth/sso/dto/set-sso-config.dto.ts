import { IsBoolean, IsOptional, IsString, IsUrl, MinLength } from 'class-validator';

/** PATCH /auth/sso/config (Milestone 15.1) — admin configures the org's IdP. */
export class SetSsoConfigDto {
  @IsUrl({ require_tld: false }, { message: 'entryPoint must be a valid URL.' })
  entryPoint: string;

  /** The IdP's X.509 signing certificate (PEM). */
  @IsString()
  @MinLength(1)
  idpCert: string;

  /** This app's SP entity id / issuer, as registered with the IdP. */
  @IsString()
  @MinLength(1)
  issuer: string;

  @IsOptional()
  @IsBoolean()
  enabled?: boolean;
}
