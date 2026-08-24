import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';

import { PrismaService } from '../../prisma/prisma.service';

interface AuthedRequest extends Request {
  user?: { userId: string; email: string };
}

/**
 * Gates every `/admin/*` route to platform (super) admins — the cross-tenant
 * operator role, distinct from the org `role` axis (Phase 21).
 *
 * Deliberately re-checks `isPlatformAdmin` from the DB on every request rather
 * than trusting a JWT claim: the flag is high-privilege and rarely changes, so
 * a per-request lookup is cheap here and means revoking admin takes effect
 * immediately (a still-valid access token can't retain admin after the flag is
 * cleared). Must be used AFTER JwtAuthGuard, which populates `req.user`.
 */
@Injectable()
export class PlatformAdminGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const userId = req.user?.userId;
    if (!userId) {
      throw new UnauthorizedException();
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { isPlatformAdmin: true },
    });

    if (!user?.isPlatformAdmin) {
      // Same opaque message whether the user exists or simply isn't an admin —
      // never reveal the existence of the admin surface to non-admins.
      throw new ForbiddenException('Not authorized.');
    }
    return true;
  }
}
