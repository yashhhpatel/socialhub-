import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Platform } from '@prisma/client';
import { Queue } from 'bullmq';

import { PrismaService } from '../prisma/prisma.service';
import { PUBLISH_QUEUES } from '../publishing/publish-queue.constants';
import { TOKEN_REFRESH_QUEUE } from '../social-accounts/token-refresh.constants';
import {
  AdminHealthDto,
  AdminQueueStatDto,
  AdminRecentErrorDto,
} from './dto/admin-system.dto';

/**
 * System & error monitoring for the admin panel (Phase 21.10). Deep health
 * (DB + Redis, not just process uptime), BullMQ queue stats, and recent 4xx/5xx
 * derived from the audit log.
 */
@Injectable()
export class AdminSystemService {
  private readonly logger = new Logger(AdminSystemService.name);
  private readonly queues: { name: string; queue: Queue }[];

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    @InjectQueue(PUBLISH_QUEUES[Platform.instagram]) instagram: Queue,
    @InjectQueue(PUBLISH_QUEUES[Platform.x]) x: Queue,
    @InjectQueue(PUBLISH_QUEUES[Platform.facebook]) facebook: Queue,
    @InjectQueue(PUBLISH_QUEUES[Platform.threads]) threads: Queue,
    @InjectQueue(PUBLISH_QUEUES[Platform.linkedin]) linkedin: Queue,
    @InjectQueue(TOKEN_REFRESH_QUEUE) tokenRefresh: Queue,
  ) {
    this.queues = [
      { name: PUBLISH_QUEUES[Platform.instagram], queue: instagram },
      { name: PUBLISH_QUEUES[Platform.x], queue: x },
      { name: PUBLISH_QUEUES[Platform.facebook], queue: facebook },
      { name: PUBLISH_QUEUES[Platform.threads], queue: threads },
      { name: PUBLISH_QUEUES[Platform.linkedin], queue: linkedin },
      { name: TOKEN_REFRESH_QUEUE, queue: tokenRefresh },
    ];
  }

  /** Deep health: actually probes Postgres and Redis, not just uptime. */
  async health(): Promise<AdminHealthDto> {
    const db = await this.checkDb();
    const redis = await this.checkRedis();
    return {
      db,
      redis,
      uptimeSeconds: Math.floor(process.uptime()),
      sentryConfigured: !!this.config.get<string>('SENTRY_DSN'),
    };
  }

  /** BullMQ job counts per queue (publish queues + token-refresh sweep). */
  async queues_(): Promise<AdminQueueStatDto[]> {
    const stats = await Promise.all(
      this.queues.map(async ({ name, queue }) => {
        try {
          const c = await queue.getJobCounts(
            'waiting',
            'active',
            'completed',
            'failed',
            'delayed',
          );
          return {
            name,
            waiting: c.waiting ?? 0,
            active: c.active ?? 0,
            completed: c.completed ?? 0,
            failed: c.failed ?? 0,
            delayed: c.delayed ?? 0,
          };
        } catch {
          // A queue whose Redis is momentarily unreachable reports zeros rather
          // than failing the whole panel.
          return { name, waiting: 0, active: 0, completed: 0, failed: 0, delayed: 0 };
        }
      }),
    );
    return stats;
  }

  /** Recent 4xx/5xx across all tenants, from the audit trail. */
  async recentErrors(limit = 25): Promise<AdminRecentErrorDto[]> {
    return this.prisma.auditLog.findMany({
      where: { statusCode: { gte: 400 } },
      orderBy: { createdAt: 'desc' },
      take: Math.min(100, Math.max(1, limit)),
      select: {
        orgId: true,
        actorEmail: true,
        method: true,
        path: true,
        statusCode: true,
        createdAt: true,
      },
    });
  }

  private async checkDb(): Promise<boolean> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return true;
    } catch (err) {
      this.logger.warn(`DB health check failed: ${errMsg(err)}`);
      return false;
    }
  }

  private async checkRedis(): Promise<boolean> {
    try {
      // A successful queue read round-trips to Redis — a good liveness proxy
      // without reaching into BullMQ's internal client.
      await this.queues[0].queue.getJobCounts('waiting');
      return true;
    } catch (err) {
      this.logger.warn(`Redis health check failed: ${errMsg(err)}`);
      return false;
    }
  }
}

function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}
