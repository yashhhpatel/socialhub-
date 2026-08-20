import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Ip,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { AccountService } from './account.service';
import { AuthService } from './auth.service';
import { AuthThrottleService } from './auth-throttle.service';
import { AuthResponseDto } from './dto/auth-response.dto';
import { LoginDto } from './dto/login.dto';
import { LogoutDto } from './dto/logout.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';
import { RequestPasswordResetDto } from './dto/request-password-reset.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly accountService: AccountService,
    private readonly throttle: AuthThrottleService,
  ) {}

  @Post('register')
  register(@Body() dto: RegisterDto): Promise<AuthResponseDto> {
    return this.authService.register(dto);
  }

  @HttpCode(HttpStatus.OK)
  @Post('login')
  login(@Body() dto: LoginDto, @Ip() ip: string): Promise<AuthResponseDto> {
    return this.authService.login({ ...dto, ip });
  }

  @HttpCode(HttpStatus.OK)
  @Post('refresh')
  refresh(@Body() dto: RefreshDto): Promise<AuthResponseDto> {
    return this.authService.refresh(dto.refreshToken);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('logout')
  async logout(@Body() dto: LogoutDto): Promise<void> {
    await this.authService.logout(dto.refreshToken);
  }

  // --- Email verification (Phase 17.1) ---

  /**
   * Consumes an emailed verification token and marks the email verified.
   * PUBLIC — the unguessable token is the credential; the user isn't
   * necessarily signed in when they click the link.
   */
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('verify-email')
  async verifyEmail(@Body() dto: VerifyEmailDto): Promise<void> {
    await this.accountService.verifyEmail(dto.token);
  }

  /** Re-sends the verification link to the signed-in user's own email. */
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('verify-email/resend')
  async resendVerification(@Req() req: AuthenticatedRequest): Promise<void> {
    await this.accountService.sendVerificationEmail(req.user.userId, req.user.email);
  }

  // --- Password reset (Phase 17.1) ---

  /**
   * Starts a password reset. PUBLIC and deliberately non-revealing: always
   * 202 whether or not the email is registered, so the form can't be used to
   * enumerate accounts.
   */
  @HttpCode(HttpStatus.ACCEPTED)
  @Post('password-reset/request')
  async requestPasswordReset(
    @Body() dto: RequestPasswordResetDto,
    @Ip() ip: string,
  ): Promise<{ message: string }> {
    // Per-IP flood guard so this public, email-sending endpoint can't be used
    // to mail-bomb an address. Throws 429 past the allowance.
    if (ip) await this.throttle.assertNotFlooding(ip, 'password-reset');
    await this.accountService.requestPasswordReset(dto.email);
    return {
      message:
        'If an account exists for that email, a password reset link has been sent.',
    };
  }

  /** Consumes a reset token and sets the new password. PUBLIC. */
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('password-reset')
  async resetPassword(@Body() dto: ResetPasswordDto): Promise<void> {
    await this.accountService.resetPassword(dto.token, dto.newPassword);
  }
}
