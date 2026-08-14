import {
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Template, UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { SearchMarketplaceDto } from './dto/search-marketplace.dto';
import { TemplateSummaryDto } from './dto/template.dto';
import { TemplatesService } from './templates.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

function toSummary(t: Omit<Template, 'canvasJson'>): TemplateSummaryDto {
  return {
    id: t.id,
    name: t.name,
    category: t.category,
    thumbnailUrl: t.thumbnailUrl,
    createdAt: t.createdAt,
  };
}

/**
 * Template marketplace (Milestone 14.1): publish a template publicly, browse
 * every org's public templates, and clone one into your own workspace.
 *
 * REGISTERED BEFORE TemplatesController (see templates.module) so the literal
 * `GET /templates/marketplace` route resolves before `GET /templates/:id`
 * would otherwise swallow "marketplace" as an id.
 */
@Controller('templates')
export class MarketplaceController {
  constructor(private readonly templates: TemplatesService) {}

  /** Public listing across all orgs — any authenticated user may browse. */
  @UseGuards(JwtAuthGuard)
  @Get('marketplace')
  async marketplace(@Query() query: SearchMarketplaceDto): Promise<TemplateSummaryDto[]> {
    const results = await this.templates.searchMarketplace(query);
    return results.map(toSummary);
  }

  /** Publishes one of the caller's own templates to the marketplace. */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
  @Post(':id/publish')
  async publish(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<TemplateSummaryDto> {
    const t = await this.templates.publish(req.user.orgId, id, req.user.userId);
    return toSummary(t);
  }

  /** Clones a public template into the caller's org. */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
  @Post(':id/clone')
  async clone(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<TemplateSummaryDto> {
    const t = await this.templates.clone(req.user.orgId, id);
    return toSummary(t);
  }
}
