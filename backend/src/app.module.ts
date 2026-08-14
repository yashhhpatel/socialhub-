import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { Module } from '@nestjs/common';
import { GraphQLModule } from '@nestjs/graphql';
import { ScheduleModule } from '@nestjs/schedule';

import { AiModule } from './ai/ai.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { AuthModule } from './auth/auth.module';
import { BrandKitsModule } from './brand-kits/brand-kits.module';
import { ConfigModule } from './config/config.module';
import { ContentModule } from './content/content.module';
import { HealthModule } from './health/health.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { PrismaModule } from './prisma/prisma.module';
import { PublishingModule } from './publishing/publishing.module';
import { QueueModule } from './queue/queue.module';
import { SocialAccountsModule } from './social-accounts/social-accounts.module';
import { TemplatesModule } from './templates/templates.module';
import { UsersModule } from './users/users.module';

/**
 * Root module. Additional feature modules (publishing, ai, analytics,
 * etc.) are added here one at a time as their milestones land — see
 * docs/blueprint/SocialHub_Implementation_Blueprint.md.
 */
@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    QueueModule,
    // Enables @Cron (Milestone 7.3): the scheduled-publish dispatcher scans
    // for due jobs on an interval.
    ScheduleModule.forRoot(),
    // Code-first GraphQL (Milestone 10.3): the schema is generated in memory
    // from the resolver's decorated types (no checked-in .graphql file).
    // `context: ({ req }) => ({ req })` hands the HTTP request to
    // GqlJwtAuthGuard so the same JWT strategy guards GraphQL. Playground off
    // — this is a machine endpoint, not a public sandbox.
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: true,
      context: ({ req }: { req: unknown }) => ({ req }),
      playground: false,
    }),
    HealthModule,
    UsersModule,
    OrganizationsModule,
    AuthModule,
    SocialAccountsModule,
    ContentModule,
    PublishingModule,
    AiModule,
    BrandKitsModule,
    TemplatesModule,
    AnalyticsModule,
  ],
})
export class AppModule {}
