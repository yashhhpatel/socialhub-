import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ContentService } from './content.service';
import { ContentAssetDto } from './dto/content-asset.dto';
import { CreateContentAssetDto } from './dto/create-content-asset.dto';
import { UpdateContentAssetDto } from './dto/update-content-asset.dto';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@Controller('content/assets')
export class ContentController {
  constructor(private readonly contentService: ContentService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateContentAssetDto,
  ): Promise<ContentAssetDto> {
    return this.contentService.create(req.user.orgId, req.user.userId, dto);
  }

  // Not in Milestone 3.1's literal expected output (only PATCH is named),
  // but there's no way to verify PATCH actually persisted anything
  // without a way to read it back — added for the same reason GET
  // /social-accounts was added in 2.4: making the milestone's own claim
  // independently checkable, not just asserted.
  @UseGuards(JwtAuthGuard)
  @Get(':id')
  get(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<ContentAssetDto> {
    return this.contentService.findByIdScoped(id, req.user.orgId);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateContentAssetDto,
  ): Promise<ContentAssetDto> {
    return this.contentService.update(id, req.user.orgId, dto);
  }
}
