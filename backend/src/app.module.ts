import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { GraphQLModule } from '@nestjs/graphql';
import { ScheduleModule } from '@nestjs/schedule';

import { AdminModule } from './admin/admin.module';
import { AiModule } from './ai/ai.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { AuditModule } from './audit/audit.module';
import { AuthModule } from './auth/auth.module';
import { BillingModule } from './billing/billing.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AuditLogInterceptor } from './common/interceptors/audit-log.interceptor';
import { SecurityHeadersMiddleware } from './common/middleware/security-headers.middleware';
import { RateLimitModule } from './common/rate-limit/rate-limit.module';
import { BrandKitsModule } from './brand-kits/brand-kits.module';
import { ConfigModule } from './config/config.module';
import { CommentsModule } from './content/comments/comments.module';
import { ContentModule } from './content/content.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { HealthModule } from './health/health.module';
import { MediaModule } from './media/media.module';
import { InvitesModule } from './organizations/invites/invites.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { PrismaModule } from './prisma/prisma.module';
import { PublishingModule } from './publishing/publishing.module';
import { QueueModule } from './queue/queue.module';
import { SocialAccountsModule } from './social-accounts/social-accounts.module';
import { TemplatesModule } from './templates/templates.module';
import { UsersModule } from './users/users.module';
import { WebhooksModule } from './webhooks/webhooks.module';

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
    InvitesModule,
    AuthModule,
    SocialAccountsModule,
    ContentModule,
    MediaModule,
    DashboardModule,
    CommentsModule,
    PublishingModule,
    AiModule,
    BrandKitsModule,
    TemplatesModule,
    AnalyticsModule,
    AuditModule,
    BillingModule,
    NotificationsModule,
    WebhooksModule,
    AdminModule,
    RateLimitModule,
  ],
  providers: [
    // Global audit trail (Milestone 15.2): records every authenticated
    // mutation. Registered app-wide so no controller can be forgotten.
    { provide: APP_INTERCEPTOR, useClass: AuditLogInterceptor },
  ],
})
export class AppModule implements NestModule {
  // Security response headers on every route (Phase 17.2).
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(SecurityHeadersMiddleware).forRoutes('*');
  }
}
