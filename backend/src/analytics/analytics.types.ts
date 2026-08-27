import { Field, GraphQLISODateTime, Int, ObjectType } from '@nestjs/graphql';

/**
 * GraphQL (code-first) shapes for the analytics endpoint (Milestone 10.3).
 * These mirror the plain interfaces in analytics-aggregation.ts one-to-one
 * — the aggregation stays framework-free and testable, and these are just
 * the transport annotations over the same fields.
 */
@ObjectType()
export class MetricsType {
  @Field(() => Int) impressions: number;
  @Field(() => Int) reach: number;
  @Field(() => Int) likes: number;
  @Field(() => Int) comments: number;
  @Field(() => Int) shares: number;
  @Field(() => Int) clicks: number;
}

@ObjectType()
export class PlatformBreakdownType {
  @Field() platform: string;
  @Field(() => Int) postCount: number;
  @Field(() => MetricsType) metrics: MetricsType;
}

@ObjectType()
export class PostMetricType {
  @Field() publishJobId: string;
  @Field(() => String, { nullable: true }) variantId: string | null;
  @Field() platform: string;
  @Field(() => String, { nullable: true }) externalPostId: string | null;
  @Field(() => MetricsType) metrics: MetricsType;
  @Field(() => GraphQLISODateTime) capturedAt: Date;
}

@ObjectType()
export class TopPostType {
  @Field() publishJobId: string;
  @Field(() => String, { nullable: true }) variantId: string | null;
  @Field() platform: string;
  @Field(() => String, { nullable: true }) externalPostId: string | null;
  @Field(() => MetricsType) metrics: MetricsType;
  @Field(() => Int) engagementScore: number;
}

@ObjectType()
export class AnalyticsOverviewType {
  @Field(() => MetricsType) totals: MetricsType;
  @Field(() => [PlatformBreakdownType]) byPlatform: PlatformBreakdownType[];
  @Field(() => Int) postCount: number;
  @Field(() => [TopPostType]) topPosts: TopPostType[];
  @Field(() => GraphQLISODateTime, { nullable: true }) lastUpdated: Date | null;
}
