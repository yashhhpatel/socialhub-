import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
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
    // Every row here belongs to the caller's org, so all are deletable.
    return templates.map((t) => ({
      id: t.id,
      name: t.name,
      category: t.category,
      thumbnailUrl: t.thumbnailUrl,
      createdAt: t.createdAt,
      isOwn: true,
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
      isOwn: true,
      canvasJson: t.canvasJson,
    };
  }

  /** Deletes one of the caller's own templates. 404s another org's template. */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    await this.templatesService.delete(id, req.user.orgId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
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
      isOwn: true,
      canvasJson: t.canvasJson,
    };
  }
}
