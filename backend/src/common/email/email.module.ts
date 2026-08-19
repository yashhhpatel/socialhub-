import { Module } from '@nestjs/common';

import { EmailService } from './email.service';

/**
 * Provides the shared transactional-email sender. EmailService is stateless
 * (reads config per call), so exporting a single provider to every importer
 * is safe — used by invites (Milestone 11.1) and auth's verification/reset
 * flows (Phase 17.1). ConfigService comes from its global module.
 */
@Module({
  providers: [EmailService],
  exports: [EmailService],
})
export class EmailModule {}
