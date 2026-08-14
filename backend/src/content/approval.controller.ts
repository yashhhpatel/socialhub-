import { Body, Controller, Get, Param, Patch, Req, UseGuards } from '@nestjs/common';
import { ContentAsset, UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { ApprovalService } from './approval.service';
import { ChangeApprovalDto, SetApprovalPolicyDto } from './dto/approval.dto';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

/**
 * Approval workflow endpoints (Milestone 13.2).
 *
 * The asset-transition route is declared at editor+ (its baseline — an
 * editor may submit/withdraw); ApprovalService enforces the finer rule that
 * only admin+ may approve/reject, which a single @Roles minimum can't
 * express. The policy toggle is admin+.
 */
@Controller('content')
export class ApprovalController {
  constructor(private readonly approval: ApprovalService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
  @Patch('assets/:id/approval')
  async changeApproval(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: ChangeApprovalDto,
  ): Promise<{ id: string; approvalStatus: ContentAsset['approvalStatus'] }> {
    const asset = await this.approval.transition(req.user.orgId, id, dto.status, {
      role: req.user.role,
    });
    return { id: asset.id, approvalStatus: asset.approvalStatus };
  }

  @UseGuards(JwtAuthGuard)
  @Get('approval-policy')
  getPolicy(@Req() req: AuthenticatedRequest): Promise<{ requiresApproval: boolean }> {
    return this.approval.getPolicy(req.user.orgId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @Patch('approval-policy')
  setPolicy(
    @Req() req: AuthenticatedRequest,
    @Body() dto: SetApprovalPolicyDto,
  ): Promise<{ requiresApproval: boolean }> {
    return this.approval.setPolicy(req.user.orgId, dto.requiresApproval);
  }
}
