import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { BrandKit } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { BrandKitsService } from './brand-kits.service';
import { BrandKitDto } from './dto/brand-kit.dto';
import { UpdateBrandKitDto } from './dto/update-brand-kit.dto';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

/**
 * Brand kit endpoints (Milestone 9.3).
 *
 * The blueprint sketches these as `/brand-kits/:org_id`, but the org is
 * taken from the authenticated JWT (`req.user.orgId`), never from the path
 * — trusting a client-supplied org id here would be an IDOR letting one
 * tenant read/patch another's brand kit. Every other module in this
 * codebase scopes by the token's org for the same reason; these routes
 * follow suit and expose no org id at all.
 */
@Controller('brand-kits')
export class BrandKitsController {
  constructor(private readonly brandKitsService: BrandKitsService) {}

  @UseGuards(JwtAuthGuard)
  @Get()
  async get(@Req() req: AuthenticatedRequest): Promise<BrandKitDto> {
    return this.toDto(await this.brandKitsService.getForOrg(req.user.orgId));
  }

  @UseGuards(JwtAuthGuard)
  @Patch()
  async update(
    @Req() req: AuthenticatedRequest,
    @Body() dto: UpdateBrandKitDto,
  ): Promise<BrandKitDto> {
    return this.toDto(await this.brandKitsService.update(req.user.orgId, dto));
  }

  private toDto(kit: BrandKit): BrandKitDto {
    return {
      id: kit.id,
      colors: kit.colors,
      fonts: kit.fonts,
      logoUrl: kit.logoUrl,
      logoPublicId: kit.logoPublicId,
      updatedAt: kit.updatedAt,
    };
  }
}
