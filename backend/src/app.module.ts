import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';

import { AiModule } from './ai/ai.module';
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
  ],
})
export class AppModule {}
