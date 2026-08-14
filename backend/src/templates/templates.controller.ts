import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateTemplateDto } from './dto/create-template.dto';
import { TemplateDetailDto, TemplateSummaryDto } from './dto/template.dto';
import { TemplatesService } from './templates.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

/**
 * Template library endpoints (Milestone 9.4). Org comes from the JWT, never
 * the path — consistent with the rest of the app's tenant scoping.
 */
@Controller('templates')
export class TemplatesController {
  constructor(private readonly templatesService: TemplatesService) {}

  @UseGuards(JwtAuthGuard)
  @Get()
  async list(@Req() req: AuthenticatedRequest): Promise<TemplateSummaryDto[]> {
    const templates = await this.templatesService.list(req.user.orgId);
    return templates.map((t) => ({
      id: t.id,
      name: t.name,
      category: t.category,
      thumbnailUrl: t.thumbnailUrl,
      createdAt: t.createdAt,
    }));
  }

  // Declared before nothing ambiguous, but kept after the bare list by the
  // same convention used elsewhere (more specific routes last).
  @UseGuards(JwtAuthGuard)
  @Get(':id')
  async get(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<TemplateDetailDto> {
    const t = await this.templatesService.findByIdScoped(id, req.user.orgId);
    return {
      id: t.id,
      name: t.name,
      category: t.category,
      thumbnailUrl: t.thumbnailUrl,
      createdAt: t.createdAt,
      canvasJson: t.canvasJson,
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateTemplateDto,
  ): Promise<TemplateDetailDto> {
    const t = await this.templatesService.create(req.user.orgId, dto);
    return {
      id: t.id,
      name: t.name,
      category: t.category,
      thumbnailUrl: t.thumbnailUrl,
      createdAt: t.createdAt,
      canvasJson: t.canvasJson,
    };
  }
}
