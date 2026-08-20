import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AccountDataService } from './account-data.service';
import { DeleteAccountDto } from './dto/delete-account.dto';
import { UserProfileDto } from './dto/user-profile.dto';
import { UsersService } from './users.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly accountData: AccountDataService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@Req() req: AuthenticatedRequest): Promise<UserProfileDto> {
    // JwtAuthGuard already guarantees req.user.userId corresponds to a
    // validated, unexpired access token (see
    // auth/strategies/jwt.strategy.ts). We still re-fetch from the DB
    // rather than trusting the token payload as-is, so a since-deleted
    // user can't keep hitting this route with a still-valid access token
    // — and so role/orgId here are always current, not whatever they were
    // at the moment the token was issued.
    const user = await this.usersService.findById(req.user.userId);

    if (!user) {
      // Token was valid but the user no longer exists (e.g. deleted
      // account). Treated as unauthorized rather than 404 — don't leak
      // account lifecycle details through status code choice.
      throw new UnauthorizedException();
    }

    return {
      id: user.id,
      email: user.email,
      role: user.role,
      orgId: user.orgId,
      emailVerified: user.emailVerifiedAt !== null,
      mfaEnabled: user.mfaEnabled,
      createdAt: user.createdAt,
    };
  }

  /**
   * GDPR data export (Phase 17.4): a JSON snapshot of everything attributable
   * to the signed-in user (and their org). Tokens/secrets excluded.
   */
  @UseGuards(JwtAuthGuard)
  @Get('me/export')
  exportData(
    @Req() req: AuthenticatedRequest,
  ): Promise<Record<string, unknown>> {
    return this.accountData.exportData(req.user.userId);
  }

  /**
   * Permanently delete the signed-in user's account (Phase 17.4). An owner
   * deletes the whole organization; a member deletes only their own data.
   * Requires the current password in the body. Irreversible.
   */
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Delete('me')
  deleteAccount(
    @Req() req: AuthenticatedRequest,
    @Body() dto: DeleteAccountDto,
  ): Promise<{ scope: 'organization' | 'user' }> {
    return this.accountData.deleteAccount(req.user.userId, dto.password);
  }
}
