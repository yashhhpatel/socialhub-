import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request, Response } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ConnectResponseDto } from './dto/connect-response.dto';
import { InstagramCallbackQueryDto } from './dto/instagram-callback-query.dto';
import { SocialAccountSummaryDto } from './dto/social-account-summary.dto';
import { XCallbackQueryDto } from './dto/x-callback-query.dto';
import { SocialAccountsService } from './social-accounts.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@Controller('social-accounts')
export class SocialAccountsController {
  constructor(
    private readonly socialAccountsService: SocialAccountsService,
    private readonly configService: ConfigService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Get()
  async list(@Req() req: AuthenticatedRequest): Promise<SocialAccountSummaryDto[]> {
    const accounts = await this.socialAccountsService.listForOrg(req.user.orgId);
    // Explicit mapping, not a raw pass-through — see SocialAccountSummaryDto's
    // doc comment on why encrypted token columns must never leave the API.
    return accounts.map((a) => ({
      id: a.id,
      platform: a.platform,
      externalAccountId: a.externalAccountId,
      status: a.status,
      expiresAt: a.expiresAt,
      createdAt: a.createdAt,
    }));
  }

  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  async disconnect(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    await this.socialAccountsService.disconnect(id, req.user.orgId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('instagram/connect')
  connectInstagram(@Req() req: AuthenticatedRequest): ConnectResponseDto {
    return {
      redirectUrl: this.socialAccountsService.buildInstagramAuthorizationUrl(
        req.user.orgId,
      ),
    };
  }

  /**
   * PUBLIC — no JwtAuthGuard. Instagram redirects the user's own browser
   * here directly after they approve/deny the authorization request;
   * there is no Authorization header available at this point, only the
   * `state` param (see SocialAccountsService) to attribute the request
   * back to an org.
   *
   * Redirects to FRONTEND_URL/settings if configured (Milestone 2.4 —
   * closes the loop explicitly deferred here since 2.2). Falls back to a
   * plain JSON confirmation if FRONTEND_URL isn't set, since Flutter
   * Web's local dev server runs on a random port by default (only fixed
   * if you run `flutter run -d chrome --web-port=<port>`) — this way
   * nothing breaks for a dev who hasn't set that up yet.
   */
  @Get('instagram/callback')
  async instagramCallback(
    @Query() query: InstagramCallbackQueryDto,
    @Res() res: Response,
  ): Promise<void> {
    if (query.error) {
      this.respondToCallback(res, {
        connectError: `Instagram authorization was not granted: ${query.error}`,
      });
      return;
    }

    if (!query.code || !query.state) {
      this.respondToCallback(res, { connectError: 'Missing code or state parameter.' });
      return;
    }

    try {
      const account = await this.socialAccountsService.handleInstagramCallback(
        query.code,
        query.state,
      );
      this.respondToCallback(res, { connected: account.platform });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Connection failed.';
      this.respondToCallback(res, { connectError: message });
    }
  }

  @UseGuards(JwtAuthGuard)
  @Post('x/connect')
  connectX(@Req() req: AuthenticatedRequest): ConnectResponseDto {
    return {
      redirectUrl: this.socialAccountsService.buildXAuthorizationUrl(req.user.orgId),
    };
  }

  /** PUBLIC — same reasoning as instagramCallback above. */
  @Get('x/callback')
  async xCallback(
    @Query() query: XCallbackQueryDto,
    @Res() res: Response,
  ): Promise<void> {
    if (query.error) {
      this.respondToCallback(res, {
        connectError: `X authorization was not granted: ${query.error}`,
      });
      return;
    }

    if (!query.code || !query.state) {
      this.respondToCallback(res, { connectError: 'Missing code or state parameter.' });
      return;
    }

    try {
      const account = await this.socialAccountsService.handleXCallback(
        query.code,
        query.state,
      );
      this.respondToCallback(res, { connected: account.platform });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Connection failed.';
      this.respondToCallback(res, { connectError: message });
    }
  }

  /**
   * Shared by both callback handlers. Redirects to the frontend's
   * Settings screen with a query param it reads on load (see
   * frontend/lib/features/social_accounts/) if FRONTEND_URL is
   * configured; otherwise returns the same info as plain JSON.
   */
  private respondToCallback(
    res: Response,
    result: { connected: string } | { connectError: string },
  ): void {
    const frontendUrl = this.configService.get<string>('FRONTEND_URL');

    if (frontendUrl) {
      const params = new URLSearchParams(result as Record<string, string>);
      res.redirect(`${frontendUrl}/settings?${params.toString()}`);
      return;
    }

    res.json(
      'connected' in result
        ? { status: 'connected', platform: result.connected }
        : { status: 'error', message: result.connectError },
    );
  }
}
