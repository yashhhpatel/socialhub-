import {
  Controller,
  Get,
  NotFoundException,
  Req,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OrganizationsService } from './organizations.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

/**
 * Read-only org overview for the Organizations settings page. Any member may
 * see their own org's name/plan/member-count; it's always the caller's own
 * org (from the JWT), never a path-supplied id.
 */
@Controller('organizations')
export class OrganizationsController {
  constructor(private readonly organizations: OrganizationsService) {}

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@Req() req: AuthenticatedRequest) {
    const overview = await this.organizations.overview(req.user.orgId);
    if (!overview) throw new NotFoundException('Organization not found.');
    return overview;
  }
}
