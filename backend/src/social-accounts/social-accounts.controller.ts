import { Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ConnectResponseDto } from './dto/connect-response.dto';
import { InstagramCallbackQueryDto } from './dto/instagram-callback-query.dto';
import { SocialAccountsService } from './social-accounts.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@Controller('social-accounts')
export class SocialAccountsController {
  constructor(private readonly socialAccountsService: SocialAccountsService) {}

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
   */
  @Get('instagram/callback')
  async instagramCallback(@Query() query: InstagramCallbackQueryDto) {
    if (query.error) {
      // User denied the request, or Instagram itself errored — either
      // way, nothing to connect. Not an HTTP error status: the browser
      // landed here successfully, it's just carrying bad news.
      return {
        status: 'error' as const,
        message: `Instagram authorization was not granted: ${query.error}`,
      };
    }

    if (!query.code || !query.state) {
      return {
        status: 'error' as const,
        message: 'Missing code or state parameter.',
      };
    }

    const account = await this.socialAccountsService.handleInstagramCallback(
      query.code,
      query.state,
    );

    // Deferred to Milestone 2.4: redirect the browser to a real frontend
    // URL once FRONTEND_URL config and the Connected Accounts screen
    // exist. A plain JSON confirmation is the honest placeholder
    // response for now, not a guess at a URL that doesn't exist yet.
    return {
      status: 'connected' as const,
      platform: account.platform,
      externalAccountId: account.externalAccountId,
    };
  }
}
