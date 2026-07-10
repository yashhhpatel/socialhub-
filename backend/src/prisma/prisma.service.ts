import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';

/**
 * Thin wrapper around PrismaClient so it can be injected via Nest's DI
 * like any other provider, with lifecycle hooks tied to the app's own
 * startup/shutdown rather than managed ad hoc per-module.
 *
 * NOTE (Prisma 7+): Prisma 7 removed its internal query engine entirely.
 * `new PrismaClient()` with no arguments now unconditionally throws
 * PrismaClientInitializationError — "needs to be constructed with a
 * non-empty, valid PrismaClientOptions" — in every environment, not just
 * this one. There is no fallback; an explicit driver adapter is required.
 * This is a separate breaking change from the prisma.config.ts one (which
 * only affects the CLI's migrate/generate commands) — this one affects
 * the generated Client at application runtime. See
 * https://pris.ly/d/driver-adapters.
 *
 * NOTE: not explicitly named in Milestone 1.1's file list ("Files/folders
 * created: /backend/src/auth/*, /backend/src/users/*"). Auth is the first
 * module in the blueprint that actually needs database access, so this is
 * the minimal shared infrastructure required to build it at all — every
 * module from here on (organizations, content, publishing, ...) will reuse
 * this same service via PrismaModule rather than each hand-rolling its own
 * client.
 */
@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor(configService: ConfigService) {
    const adapter = new PrismaPg({
      connectionString: configService.getOrThrow<string>('DATABASE_URL'),
    });
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
