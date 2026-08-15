import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { AuditLog, UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuditService } from './audit.service';
import { ListAuditLogsDto } from './dto/list-audit-logs.dto';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

/**
 * The org's audit trail (Milestone 15.2). admin+ only — a full record of who
 * did what is a management/compliance view, not something every member reads.
 */
@Controller('audit-logs')
export class AuditController {
  constructor(private readonly audit: AuditService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @Get()
  list(
    @Req() req: AuthenticatedRequest,
    @Query() query: ListAuditLogsDto,
  ): Promise<AuditLog[]> {
    return this.audit.list(req.user.orgId, query);
  }
}
