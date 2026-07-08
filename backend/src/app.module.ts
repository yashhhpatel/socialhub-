import { Module } from '@nestjs/common';

import { ConfigModule } from './config/config.module';
import { HealthModule } from './health/health.module';

/**
 * Root module. Additional feature modules (auth, organizations,
 * social-accounts, etc.) are added here one at a time as their milestones
 * land — see docs/blueprint/SocialHub_Implementation_Blueprint.md.
 */
@Module({
  imports: [ConfigModule, HealthModule],
})
export class AppModule {}
