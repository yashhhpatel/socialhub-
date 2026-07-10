import {
  Controller,
  Get,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UserProfileDto } from './dto/user-profile.dto';
import { UsersService } from './users.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

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
      createdAt: user.createdAt,
    };
  }
}
