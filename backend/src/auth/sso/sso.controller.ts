import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UserRole } from '@prisma/client';
import { Request, Response } from 'express';

import { JwtAuthGuard } from '../guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { PrismaService } from '../../prisma/prisma.service';
import { SetSsoConfigDto } from './dto/set-sso-config.dto';
import { SsoService } from './sso.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

/**
 * SAML SSO endpoints (Milestone 15.1). The login/callback routes are PUBLIC
 * (the user has no session yet); the config route is admin+.
 */
@Controller('auth/sso')
export class SsoController {
  constructor(
    private readonly sso: SsoService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /** Starts SSO for an org: redirects the browser to that org's IdP. */
  @Get(':orgId/login')
  async login(
    @Param('orgId') orgId: string,
    @Req() req: Request,
    @Res() res: Response,
  ): Promise<void> {
    const url = await this.sso.buildLoginUrl(orgId, req.headers.host ?? '');
    res.redirect(url);
  }

  /**
   * The IdP's assertion consumer (ACS). The IdP POSTs the signed
   * SAMLResponse here; on success we hand the session back to the frontend.
   */
  @Post('callback')
  async callback(
    @Body() body: { SAMLResponse?: string; RelayState?: string },
    @Res() res: Response,
  ): Promise<void> {
    const session = await this.sso.handleCallback(
      body.SAMLResponse ?? '',
      body.RelayState ?? '',
    );

    const frontendUrl = this.config.get<string>('FRONTEND_URL');
    if (frontendUrl) {
      // Tokens go in the URL FRAGMENT (#), which browsers don't send to
      // servers or store in most logs — the same trade-off the OAuth
      // callbacks make. The frontend SSO screen reads them and stores them.
      const params = new URLSearchParams({
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      });
      res.redirect(`${frontendUrl}/#/sso-callback?${params.toString()}`);
      return;
    }

    // No frontend configured (API-only testing) — return the session as JSON.
    res.json(session);
  }

  /** Configures the org's IdP (admin+). Upserts the single SsoConfig. */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @Patch('config')
  async setConfig(
    @Req() req: AuthenticatedRequest,
    @Body() dto: SetSsoConfigDto,
  ): Promise<{ enabled: boolean; entryPoint: string; issuer: string }> {
    const data = {
      entryPoint: dto.entryPoint,
      idpCert: dto.idpCert,
      issuer: dto.issuer,
      ...(dto.enabled !== undefined ? { enabled: dto.enabled } : {}),
    };
    const saved = await this.prisma.ssoConfig.upsert({
      where: { orgId: req.user.orgId },
      create: { orgId: req.user.orgId, ...data },
      update: data,
    });
    // Never echo the certificate back.
    return { enabled: saved.enabled, entryPoint: saved.entryPoint, issuer: saved.issuer };
  }
}
