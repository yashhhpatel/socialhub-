import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

/**
 * Thin wrapper around PrismaClient so it can be injected via Nest's DI
 * like any other provider, with lifecycle hooks tied to the app's own
 * startup/shutdown rather than managed ad hoc per-module.
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
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
