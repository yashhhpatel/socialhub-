import { Module } from '@nestjs/common';

import { EmailService } from '../../common/email/email.service';
import {
  InvitesAdminController,
  InvitesPublicController,
} from './invites.controller';
import { InvitesService } from './invites.service';

/**
 * Team invites (Milestone 11.1). EmailService is provided here (it's
 * stateless and only invites use it so far); PrismaService and ConfigService
 * come from their global modules.
 */
@Module({
  controllers: [InvitesAdminController, InvitesPublicController],
  providers: [InvitesService, EmailService],
  exports: [InvitesService],
})
export class InvitesModule {}
