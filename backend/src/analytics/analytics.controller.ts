import { Controller, Get, Param, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AnalyticsOverview, MetricRow } from './analytics-aggregation';
import { AnalyticsQueryService } from './analytics-query.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

/**
 * REST fallback for analytics (Milestone 10.3), per the REST API design —
 * the same data as the GraphQL endpoint for clients that don't speak
 * GraphQL. Backed by the identical AnalyticsQueryService, so the two can't
 * report different numbers.
 */
@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsQueryService) {}

  @UseGuards(JwtAuthGuard)
  @Get('overview')
  overview(@Req() req: AuthenticatedRequest): Promise<AnalyticsOverview> {
    return this.analytics.overview(req.user.orgId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('posts/:variantId')
  postMetrics(
    @Req() req: AuthenticatedRequest,
    @Param('variantId') variantId: string,
  ): Promise<MetricRow[]> {
    return this.analytics.postMetrics(req.user.orgId, variantId);
  }
}
