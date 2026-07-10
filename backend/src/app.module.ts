import { Module } from '@nestjs/common';

import { AuthModule } from './auth/auth.module';
import { ConfigModule } from './config/config.module';
import { HealthModule } from './health/health.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';

/**
 * Root module. Additional feature modules (social-accounts, content,
 * publishing, etc.) are added here one at a time as their milestones
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
  ],
})
export class AppModule {}
