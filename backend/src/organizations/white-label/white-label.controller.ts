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
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { SetWhiteLabelDto } from './dto/set-white-label.dto';
import { WhiteLabel, WhiteLabelService } from './white-label.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

/**
 * Org white-label branding (Milestone 15.4). Any member can READ their org's
 * branding (the app applies it on load); only admin+ can change it, and only
 * for their own org (the :orgId path must match the token's org).
 */
@Controller('organizations')
export class WhiteLabelController {
  constructor(private readonly whiteLabel: WhiteLabelService) {}

  @UseGuards(JwtAuthGuard)
  @Get('white-label')
  get(@Req() req: AuthenticatedRequest): Promise<WhiteLabel> {
    return this.whiteLabel.get(req.user.orgId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @Patch(':orgId/white-label')
  setWhiteLabel(
    @Req() req: AuthenticatedRequest,
    @Param('orgId') orgId: string,
    @Body() dto: SetWhiteLabelDto,
  ): Promise<WhiteLabel> {
    if (req.user.orgId !== orgId) {
      throw new ForbiddenException('You can only brand your own organization.');
    }
    return this.whiteLabel.set(orgId, dto);
  }
}
