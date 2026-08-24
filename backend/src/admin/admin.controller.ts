import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminOverviewService } from './admin-overview.service';
import { AdminOverviewDto } from './dto/admin-overview.dto';
import { PlatformAdminGuard } from './guards/platform-admin.guard';

interface AuthedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

/**
 * Platform admin API (Phase 21). Every route here is gated by
 * JwtAuthGuard + PlatformAdminGuard, so only platform admins reach it. Reads
 * are cross-tenant; secrets are never selected. Feature endpoints are added by
 * later milestones — this base carries the identity check.
 */
@UseGuards(JwtAuthGuard, PlatformAdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly overviewService: AdminOverviewService) {}

  /** Confirms the caller is a platform admin (drives the admin shell gate). */
  @Get('me')
  me(@Req() req: AuthedRequest): { userId: string; email: string; isPlatformAdmin: true } {
    return { userId: req.user.userId, email: req.user.email, isPlatformAdmin: true };
  }

  /** Cross-tenant platform KPIs for the Overview dashboard (21.2). */
  @Get('overview')
  overview(): Promise<AdminOverviewDto> {
    return this.overviewService.overview();
  }
}
