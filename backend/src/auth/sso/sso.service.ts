import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SAML } from '@node-saml/node-saml';
import { SsoConfig } from '@prisma/client';

import { AuthResponseDto } from '../dto/auth-response.dto';
import { AuthService } from '../auth.service';
import { PrismaService } from '../../prisma/prisma.service';
import { UsersService } from '../../users/users.service';

/**
 * SAML SSO (Milestone 15.1). Multi-tenant: each org configures its own IdP
 * (SsoConfig), and the org is carried through the flow as SAML RelayState so
 * the single callback endpoint knows which org's config to validate the
 * assertion against.
 *
 * The user must already be a member of the org — an SSO assertion
 * authenticates an identity, it doesn't grant membership. Just-in-time
 * provisioning is a deliberate future enhancement, not silent account
 * creation from any IdP that happens to sign a response.
 *
 * The IdP itself can't be exercised in CI (there's no live Okta/Azure), so
 * the assertion-parsing seam (node-saml's validatePostResponse) is what the
 * unit tests mock — the same boundary a real integration would stub.
 */
@Injectable()
export class SsoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly auth: AuthService,
    private readonly config: ConfigService,
  ) {}

  /** Builds the redirect URL that starts login at the org's IdP. */
  async buildLoginUrl(orgId: string, host: string): Promise<string> {
    const saml = this.samlFor(await this.requireConfig(orgId));
    // RelayState carries the org id back to the callback.
    return saml.getAuthorizeUrlAsync(orgId, host, {});
  }

  /**
   * Handles the IdP's SAMLResponse POST: validates the assertion against the
   * org's configured certificate, resolves the asserted email to a member of
   * that org, and issues a normal SocialHub session.
   */
  async handleCallback(samlResponse: string, relayState: string): Promise<AuthResponseDto> {
    if (!relayState) {
      throw new BadRequestException('Missing RelayState (organization) on the SSO response.');
    }
    const orgId = relayState;
    const saml = this.samlFor(await this.requireConfig(orgId));

    let profile: { email?: string | null; nameID?: string | null } | null;
    try {
      const result = await saml.validatePostResponseAsync({
        SAMLResponse: samlResponse,
        RelayState: relayState,
      });
      profile = result.profile;
    } catch {
      // Signature/format/expiry failures all collapse to one opaque error —
      // never leak which check a forged response tripped.
      throw new UnauthorizedException('The SSO response could not be verified.');
    }

    const email = (profile?.email ?? profile?.nameID)?.trim().toLowerCase();
    if (!email) {
      throw new UnauthorizedException('The SSO response carried no email to sign in with.');
    }

    const user = await this.users.findByEmail(email);
    // The asserted identity must be an existing member of THIS org.
    if (!user || user.orgId !== orgId) {
      throw new UnauthorizedException(
        'No SocialHub account for this identity in this organization. Ask an admin to invite you first.',
      );
    }

    return this.auth.issueSession(user.id, user.email, user.role, user.orgId);
  }

  private async requireConfig(orgId: string): Promise<SsoConfig> {
    const config = await this.prisma.ssoConfig.findUnique({ where: { orgId } });
    if (!config || !config.enabled) {
      throw new BadRequestException('SSO is not configured for this organization.');
    }
    return config;
  }

  private samlFor(config: SsoConfig): SAML {
    return new SAML({
      entryPoint: config.entryPoint,
      issuer: config.issuer,
      idpCert: config.idpCert,
      callbackUrl: this.callbackUrl(),
      // Assertions must be signed by the IdP — the whole basis of trust here.
      wantAuthnResponseSigned: true,
      wantAssertionsSigned: true,
      audience: config.issuer,
    });
  }

  private callbackUrl(): string {
    return this.config.get<string>(
      'SSO_CALLBACK_URL',
      'http://localhost:3000/auth/sso/callback',
    );
  }
}
