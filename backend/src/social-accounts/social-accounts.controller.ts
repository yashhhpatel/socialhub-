import {
  BadRequestException,
  Body,
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
import { Platform, UserRole } from '@prisma/client';
import { Request, Response } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { parseMetaSignedRequest } from '../common/crypto/meta-signed-request.util';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { ConnectResponseDto } from './dto/connect-response.dto';
import { FacebookCallbackQueryDto } from './dto/facebook-callback-query.dto';
import { InstagramCallbackQueryDto } from './dto/instagram-callback-query.dto';
import { LinkedInCallbackQueryDto } from './dto/linkedin-callback-query.dto';
import { ThreadsCallbackQueryDto } from './dto/threads-callback-query.dto';
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

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  async disconnect(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    await this.socialAccountsService.disconnect(id, req.user.orgId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
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

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
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

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @Post('facebook/connect')
  connectFacebook(@Req() req: AuthenticatedRequest): ConnectResponseDto {
    return {
      redirectUrl: this.socialAccountsService.buildFacebookAuthorizationUrl(
        req.user.orgId,
      ),
    };
  }

  /** PUBLIC — same reasoning as instagramCallback above. */
  @Get('facebook/callback')
  async facebookCallback(
    @Query() query: FacebookCallbackQueryDto,
    @Res() res: Response,
  ): Promise<void> {
    if (query.error) {
      this.respondToCallback(res, {
        connectError: `Facebook authorization was not granted: ${query.error}`,
      });
      return;
    }

    if (!query.code || !query.state) {
      this.respondToCallback(res, { connectError: 'Missing code or state parameter.' });
      return;
    }

    try {
      const account = await this.socialAccountsService.handleFacebookCallback(
        query.code,
        query.state,
      );
      this.respondToCallback(res, { connected: account.platform });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Connection failed.';
      this.respondToCallback(res, { connectError: message });
    }
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @Post('threads/connect')
  connectThreads(@Req() req: AuthenticatedRequest): ConnectResponseDto {
    return {
      redirectUrl: this.socialAccountsService.buildThreadsAuthorizationUrl(
        req.user.orgId,
      ),
    };
  }

  /** PUBLIC — same reasoning as instagramCallback above. */
  @Get('threads/callback')
  async threadsCallback(
    @Query() query: ThreadsCallbackQueryDto,
    @Res() res: Response,
  ): Promise<void> {
    if (query.error) {
      this.respondToCallback(res, {
        connectError: `Threads authorization was not granted: ${query.error}`,
      });
      return;
    }

    if (!query.code || !query.state) {
      this.respondToCallback(res, { connectError: 'Missing code or state parameter.' });
      return;
    }

    try {
      const account = await this.socialAccountsService.handleThreadsCallback(
        query.code,
        query.state,
      );
      this.respondToCallback(res, { connected: account.platform });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Connection failed.';
      this.respondToCallback(res, { connectError: message });
    }
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @Post('linkedin/connect')
  connectLinkedIn(@Req() req: AuthenticatedRequest): ConnectResponseDto {
    return {
      redirectUrl: this.socialAccountsService.buildLinkedInAuthorizationUrl(
        req.user.orgId,
      ),
    };
  }

  /** PUBLIC — same reasoning as instagramCallback above. */
  @Get('linkedin/callback')
  async linkedinCallback(
    @Query() query: LinkedInCallbackQueryDto,
    @Res() res: Response,
  ): Promise<void> {
    if (query.error) {
      this.respondToCallback(res, {
        connectError: `LinkedIn authorization was not granted: ${query.error}`,
      });
      return;
    }

    if (!query.code || !query.state) {
      this.respondToCallback(res, { connectError: 'Missing code or state parameter.' });
      return;
    }

    try {
      const account = await this.socialAccountsService.handleLinkedInCallback(
        query.code,
        query.state,
      );
      this.respondToCallback(res, { connected: account.platform });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Connection failed.';
      this.respondToCallback(res, { connectError: message });
    }
  }

  // --- Meta compliance callbacks (Phase 16) ---
  //
  // Meta calls these — not a signed-in user — so they are PUBLIC (no
  // JwtAuthGuard) and authenticated instead by the `signed_request` body,
  // an HMAC-SHA256 signature keyed on the app secret. Every Meta app that
  // requests permissions MUST register a deauthorize and a data-deletion
  // callback; these satisfy that requirement for facebook/instagram/threads.

  /**
   * Deauthorize callback: Meta pings this when a user removes our app from
   * their account. We purge that user's connected accounts for the platform.
   * PUBLIC — trust comes from the verified signed_request, not a session.
   */
  @Post(':platform/deauthorize')
  @HttpCode(HttpStatus.OK)
  async deauthorize(
    @Param('platform') platformParam: string,
    @Body('signed_request') signedRequest: string,
  ): Promise<{ success: boolean }> {
    const { platform, userId } = this.verifyMetaSignedRequest(
      platformParam,
      signedRequest,
    );
    await this.socialAccountsService.purgePlatformUser(platform, userId);
    return { success: true };
  }

  /**
   * Data-deletion request callback: Meta calls this when a user requests
   * deletion of the data our app holds about them. We purge their accounts,
   * record the request, and return the { url, confirmation_code } Meta
   * requires so the user can check deletion status. PUBLIC — see above.
   */
  @Post(':platform/data-deletion')
  @HttpCode(HttpStatus.OK)
  async dataDeletion(
    @Param('platform') platformParam: string,
    @Body('signed_request') signedRequest: string,
    @Req() req: Request,
  ): Promise<{ url: string; confirmation_code: string }> {
    const { platform, userId } = this.verifyMetaSignedRequest(
      platformParam,
      signedRequest,
    );
    const confirmationCode = await this.socialAccountsService.recordDataDeletion(
      platform,
      userId,
    );
    // Absolute, publicly-reachable status URL Meta shows the user. Built from
    // the request host so it works behind ngrok/whatever domain is in front.
    const proto = req.get('x-forwarded-proto') ?? req.protocol;
    const url =
      `${proto}://${req.get('host')}/social-accounts/data-deletion/status` +
      `?code=${confirmationCode}`;
    return { url, confirmation_code: confirmationCode };
  }

  /**
   * Human-readable status page the data-deletion `url` above points to.
   * PUBLIC by design — the confirmation code is the unguessable capability.
   */
  @Get('data-deletion/status')
  async dataDeletionStatus(
    @Query('code') code: string,
  ): Promise<{ code: string; status: string; completedAt: string | null }> {
    const record = code
      ? await this.socialAccountsService.getDataDeletionStatus(code)
      : null;
    if (!record) {
      return { code: code ?? '', status: 'not_found', completedAt: null };
    }
    return {
      code: record.confirmationCode,
      status: record.status,
      completedAt: record.createdAt.toISOString(),
    };
  }

  /**
   * Verifies a Meta signed_request against the platform's app secret and
   * returns the resolved platform enum + the authorizing user id. Throws
   * BadRequestException for a non-Meta platform, an unconfigured secret, or
   * a missing/forged signature — never proceed on an unverified request.
   */
  private verifyMetaSignedRequest(
    platformParam: string,
    signedRequest: string,
  ): { platform: Platform; userId: string } {
    const secret = this.metaAppSecret(platformParam);
    if (!secret) {
      throw new BadRequestException(
        `'${platformParam}' is not a Meta platform with compliance callbacks.`,
      );
    }
    if (!signedRequest) {
      throw new BadRequestException('Missing signed_request.');
    }
    const payload = parseMetaSignedRequest(signedRequest, secret);
    if (!payload) {
      throw new BadRequestException('Invalid or forged signed_request.');
    }
    return { platform: platformParam as Platform, userId: payload.user_id };
  }

  /**
   * The app secret to verify a Meta signed_request for this platform, or
   * null if the platform isn't a Meta one. Mirrors each adapter's env var
   * naming (Facebook accepts the *_APP_SECRET / *_CLIENT_SECRET fallback).
   */
  private metaAppSecret(platform: string): string | null {
    switch (platform) {
      case 'facebook':
        return (
          this.configService.get<string>('FACEBOOK_APP_SECRET') ??
          this.configService.get<string>('FACEBOOK_CLIENT_SECRET') ??
          null
        );
      case 'instagram':
        return this.configService.get<string>('INSTAGRAM_CLIENT_SECRET') ?? null;
      case 'threads':
        return this.configService.get<string>('THREADS_CLIENT_SECRET') ?? null;
      default:
        return null;
    }
  }

  /**
   * Shared by every platform's callback handler. Redirects to the
   * frontend's Settings screen with a query param it reads on load (see
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
      // `/#/settings`, NOT `/settings`. The Flutter app uses go_router's
      // default hash URL strategy, so `/settings` is not a real path —
      // it is a fragment. Redirecting to the bare path hit the static
      // host's 404 page every time, which meant EVERY OAuth outcome,
      // success and failure alike, was discarded before the app saw it:
      // the connected/connectError params below are read by
      // SocialAccountsScreen (via state.uri.queryParameters) and were
      // never arriving. It also made platform errors undiagnosable —
      // the real cause of a failed connect could only be recovered by
      // reading it out of the 404 page's address bar by hand.
      res.redirect(`${frontendUrl}/#/settings?${params.toString()}`);
      return;
    }

    res.json(
      'connected' in result
        ? { status: 'connected', platform: result.connected }
        : { status: 'error', message: result.connectError },
    );
  }
}
