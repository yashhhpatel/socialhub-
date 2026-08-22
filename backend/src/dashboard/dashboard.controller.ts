import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DashboardService } from './dashboard.service';
import { DashboardSummaryDto } from './dto/dashboard-summary.dto';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

/// Overview dashboard summary (real data, org-scoped). Any signed-in member.
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @UseGuards(JwtAuthGuard)
  @Get('summary')
  summary(@Req() req: AuthenticatedRequest): Promise<DashboardSummaryDto> {
    return this.dashboard.summary(req.user.orgId);
  }
}
