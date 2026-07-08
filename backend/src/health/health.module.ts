import { Module } from '@nestjs/common';

import { HealthController } from './health.controller';

/**
 * NOTE: this checks only that the process is up and serving requests.
 * A database connectivity check is added to this endpoint in Milestone 0.4
 * once Prisma is wired in — deliberately not attempted here, since no DB
 * client exists yet in this milestone's scope.
 */
@Module({
  controllers: [HealthController],
})
export class HealthModule {}
