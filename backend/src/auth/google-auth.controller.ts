import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import { Response } from 'express';

import { AuthResponseDto } from './dto/auth-response.dto';
import { GoogleExchangeDto } from './dto/google-exchange.dto';
import { GoogleAuthService } from './google-auth.service';

/**
 * "Continue with Google" endpoints (server-side authorization-code flow).
 * These are PUBLIC — they *are* the sign-in path. Start/callback are browser
 * redirects; exchange is the SPA swapping its one-time ticket for a session.
 */
@Controller('auth/google')
export class GoogleAuthController {
  constructor(private readonly google: GoogleAuthService) {}

  /** Kicks off the flow by redirecting the browser to Google's consent screen. */
  @Get('start')
  async start(@Res() res: Response): Promise<void> {
    if (!this.google.enabled) {
      // Degrade gracefully rather than showing a raw 503 page — the SPA reads
      // the error param and surfaces a friendly message on the login screen.
      res.redirect(this.google.failureRedirect());
      return;
    }
    res.redirect(await this.google.buildConsentUrl());
  }

  /** Google redirects here with an auth code (or an error). */
  @Get('callback')
  async callback(
    @Res() res: Response,
    @Query('code') code?: string,
    @Query('state') state?: string,
    @Query('error') error?: string,
  ): Promise<void> {
    if (error || !code || !state) {
      res.redirect(this.google.failureRedirect());
      return;
    }
    try {
      res.redirect(await this.google.handleCallback(code, state));
    } catch {
      // Any verification/exchange failure collapses to the same friendly bounce.
      res.redirect(this.google.failureRedirect());
    }
  }

  /** Swap the single-use handoff ticket for the normal session response. */
  @HttpCode(HttpStatus.OK)
  @Post('exchange')
  exchange(@Body() dto: GoogleExchangeDto): Promise<AuthResponseDto> {
    return this.google.exchangeTicket(dto.ticket);
  }
}
