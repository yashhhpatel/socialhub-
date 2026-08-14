import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { User, UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ChangeRoleDto } from './dto/change-role.dto';
import { MembersService } from './members.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

function memberSummary(user: User) {
  // No passwordHash ever leaves the API.
  return {
    id: user.id,
    email: user.email,
    role: user.role,
    createdAt: user.createdAt,
  };
}

/**
 * Team roster + role management (Milestone 11.2). admin+ only, and always
 * scoped to the caller's own org — the `:orgId` in the path must match the
 * token's org.
 */
@Controller('organizations/:orgId/members')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.admin)
export class MembersController {
  constructor(private readonly members: MembersService) {}

  private assertOwnOrg(req: AuthenticatedRequest, orgId: string): void {
    if (req.user.orgId !== orgId) {
      throw new ForbiddenException('You can only manage your own organization.');
    }
  }

  @Get()
  async list(@Req() req: AuthenticatedRequest, @Param('orgId') orgId: string) {
    this.assertOwnOrg(req, orgId);
    const members = await this.members.list(orgId);
    return members.map(memberSummary);
  }

  @Patch(':userId/role')
  async changeRole(
    @Req() req: AuthenticatedRequest,
    @Param('orgId') orgId: string,
    @Param('userId') userId: string,
    @Body() dto: ChangeRoleDto,
  ) {
    this.assertOwnOrg(req, orgId);
    const updated = await this.members.changeRole(orgId, userId, dto.role, {
      userId: req.user.userId,
      role: req.user.role,
    });
    return memberSummary(updated);
  }
}
