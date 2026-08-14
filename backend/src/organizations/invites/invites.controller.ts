import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Invite, UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AcceptInviteDto } from './dto/accept-invite.dto';
import { CreateInviteDto } from './dto/create-invite.dto';
import { InvitesService } from './invites.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

function inviteSummary(invite: Invite) {
  // Never the tokenHash — the raw token only ever exists in the email.
  return {
    id: invite.id,
    email: invite.email,
    role: invite.role,
    status: invite.status,
    expiresAt: invite.expiresAt,
    createdAt: invite.createdAt,
  };
}

/**
 * Admin-side invite management (Milestone 11.1). admin+ only, and always
 * scoped to the caller's own org — the `:orgId` in the path must match the
 * token's org (an admin cannot manage another tenant's invites), enforced
 * explicitly here in addition to the role gate.
 */
@Controller('organizations/:orgId')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.admin)
export class InvitesAdminController {
  constructor(private readonly invites: InvitesService) {}

  private assertOwnOrg(req: AuthenticatedRequest, orgId: string): void {
    if (req.user.orgId !== orgId) {
      throw new ForbiddenException('You can only manage your own organization.');
    }
  }

  @Post('invite')
  async invite(
    @Req() req: AuthenticatedRequest,
    @Param('orgId') orgId: string,
    @Body() dto: CreateInviteDto,
  ) {
    this.assertOwnOrg(req, orgId);
    const invite = await this.invites.create(
      orgId,
      { userId: req.user.userId, role: req.user.role },
      dto,
    );
    return inviteSummary(invite);
  }

  @Get('invites')
  async list(@Req() req: AuthenticatedRequest, @Param('orgId') orgId: string) {
    this.assertOwnOrg(req, orgId);
    const invites = await this.invites.listPending(orgId);
    return invites.map(inviteSummary);
  }

  @Delete('invites/:inviteId')
  @HttpCode(HttpStatus.NO_CONTENT)
  async revoke(
    @Req() req: AuthenticatedRequest,
    @Param('orgId') orgId: string,
    @Param('inviteId') inviteId: string,
  ): Promise<void> {
    this.assertOwnOrg(req, orgId);
    await this.invites.revoke(inviteId, orgId);
  }
}

/**
 * PUBLIC accept endpoint (Milestone 11.1) — no JwtAuthGuard, because the
 * invitee has no account yet. The single-use token IS the authorization;
 * everything about the new user (email, role, org) comes from the invite it
 * resolves to, never from the request body.
 */
@Controller('invites')
export class InvitesPublicController {
  constructor(private readonly invites: InvitesService) {}

  @Post(':token/accept')
  async accept(@Param('token') token: string, @Body() dto: AcceptInviteDto) {
    const user = await this.invites.accept(token, dto);
    return { userId: user.id, email: user.email, role: user.role, orgId: user.orgId };
  }
}
