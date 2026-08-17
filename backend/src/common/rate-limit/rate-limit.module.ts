import { Inject, Module, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { Redis } from 'ioredis';

import { OrgRateLimitGuard } from '../guards/org-rate-limit.guard';
import { RATE_LIMIT_REDIS } from './rate-limit.tokens';

/**
 * Per-org rate limiting (Milestone 15.3). Registers the guard app-wide via
 * APP_GUARD and provides its own ioredis client — separate from BullMQ's
 * connection so queue backpressure and rate-limit counters never contend on
 * one client. The client fails fast (one retry) so a Redis outage surfaces
 * as the guard's fail-open path rather than a hang.
 */
@Module({
  providers: [
    {
      provide: RATE_LIMIT_REDIS,
      inject: [ConfigService],
      useFactory: (config: ConfigService) =>
        new Redis({
          host: config.get<string>('REDIS_HOST', 'localhost'),
          port: Number(config.get('REDIS_PORT', 6379)),
          password: config.get<string>('REDIS_PASSWORD') || undefined,
          maxRetriesPerRequest: 1,
          lazyConnect: true,
        }),
    },
    { provide: APP_GUARD, useClass: OrgRateLimitGuard },
  ],
})
export class RateLimitModule implements OnModuleDestroy {
  constructor(@Inject(RATE_LIMIT_REDIS) private readonly redis: Redis) {}

  async onModuleDestroy(): Promise<void> {
    // Close the dedicated connection cleanly on shutdown.
    await this.redis.quit().catch(() => undefined);
  }
}
