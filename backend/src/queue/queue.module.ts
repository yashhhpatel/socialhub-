import { BullModule } from '@nestjs/bullmq';
import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * BullMQ infrastructure (Milestone 7.1).
 *
 * Registers the single Redis connection every queue in the app shares.
 * Global so that any feature module can register its own queues with
 * `BullModule.registerQueue(...)` and inject them, without re-declaring the
 * connection — the per-platform publish queues in Milestone 7.2 do exactly
 * that.
 *
 * The connection comes from ConfigService (ConfigModule is global), so it
 * points at the local docker-compose Redis in development and at the managed
 * instance in staging/production with no code change.
 */
@Global()
@Module({
  imports: [
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        connection: {
          host: config.get<string>('REDIS_HOST', 'localhost'),
          port: config.get<number>('REDIS_PORT', 6379),
          // Empty string means "no auth" (local Redis); only pass a real
          // password through so ioredis doesn't AUTH against a server that
          // has none.
          password: config.get<string>('REDIS_PASSWORD') || undefined,
        },
        // Sensible queue-wide defaults. Per-attempt retry/backoff for the
        // publish queues is set in Milestone 7.2 where those queues live.
        defaultJobOptions: {
          // Keep the last successes/failures for inspection, but don't let
          // Redis grow unbounded with finished-job records.
          removeOnComplete: 1000,
          removeOnFail: 5000,
        },
      }),
    }),
  ],
  exports: [BullModule],
})
export class QueueModule {}
