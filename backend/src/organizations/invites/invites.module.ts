import { Module } from '@nestjs/common';

import { BillingModule } from '../../billing/billing.module';
import { EmailModule } from '../../common/email/email.module';
import {
  InvitesAdminController,
  InvitesPublicController,
} from './invites.controller';
import { InvitesService } from './invites.service';

/**
 * Team invites (Milestone 11.1). EmailService now comes from the shared
 * EmailModule (Phase 17.1, once auth also needed it); PrismaService and
 * ConfigService come from their global modules.
 */
@Module({
  imports: [EmailModule, BillingModule],
  controllers: [InvitesAdminController, InvitesPublicController],
  providers: [InvitesService],
  exports: [InvitesService],
})
export class InvitesModule {}
