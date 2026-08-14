import { UseGuards } from '@nestjs/common';
import { Args, Context, Query, Resolver } from '@nestjs/graphql';

import { GqlJwtAuthGuard } from '../auth/guards/gql-jwt-auth.guard';
import { AnalyticsQueryService } from './analytics-query.service';
import { AnalyticsOverviewType, PostMetricType } from './analytics.types';

interface GqlContext {
  req: { user: { orgId: string } };
}

/**
 * GraphQL analytics endpoint (Milestone 10.3). The dashboard fetches its
 * whole overview — totals, per-platform breakdown, top posts — in one round
 * trip via `analyticsOverview`, and drills into a single post's numbers with
 * `postMetrics(variantId)`. Org is taken from the authenticated JWT in the
 * GraphQL context, never a client argument.
 */
@Resolver()
@UseGuards(GqlJwtAuthGuard)
export class AnalyticsResolver {
  constructor(private readonly analytics: AnalyticsQueryService) {}

  @Query(() => AnalyticsOverviewType)
  analyticsOverview(@Context() ctx: GqlContext): Promise<AnalyticsOverviewType> {
    return this.analytics.overview(ctx.req.user.orgId);
  }

  @Query(() => [PostMetricType])
  postMetrics(
    @Context() ctx: GqlContext,
    @Args('variantId') variantId: string,
  ): Promise<PostMetricType[]> {
    return this.analytics.postMetrics(ctx.req.user.orgId, variantId);
  }
}
