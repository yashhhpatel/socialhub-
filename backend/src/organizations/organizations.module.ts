import { Module } from '@nestjs/common';

import { MembersController } from './members/members.controller';
import { MembersService } from './members/members.service';
import { OrganizationsController } from './organizations.controller';
import { OrganizationsService } from './organizations.service';
import { WhiteLabelController } from './white-label/white-label.controller';
import { WhiteLabelService } from './white-label/white-label.service';

/**
 * OrganizationsService is the internal building block registration uses
 * (see AuthService.register). Milestone 11.2 adds team roster + role
 * management (MembersController); 15.4 adds white-label branding. Invites
 * live in their own InvitesModule.
 */
@Module({
  controllers: [OrganizationsController, MembersController, WhiteLabelController],
  providers: [OrganizationsService, MembersService, WhiteLabelService],
  exports: [OrganizationsService],
})
export class OrganizationsModule {}
