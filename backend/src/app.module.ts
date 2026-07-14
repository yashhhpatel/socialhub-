import { Module } from '@nestjs/common';

import { AuthModule } from './auth/auth.module';
import { ConfigModule } from './config/config.module';
import { HealthModule } from './health/health.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { PrismaModule } from './prisma/prisma.module';
import { SocialAccountsModule } from './social-accounts/social-accounts.module';
import { UsersModule } from './users/users.module';

/**
 * Root module. Additional feature modules (content, publishing, ai,
 * analytics, etc.) are added here one at a time as their milestones
 * land — see docs/blueprint/SocialHub_Implementation_Blueprint.md.
 */
@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    HealthModule,
    UsersModule,
    OrganizationsModule,
    AuthModule,
    SocialAccountsModule,
  ],
})
export class AppModule {}
