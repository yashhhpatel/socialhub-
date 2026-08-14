import { Module } from '@nestjs/common';

import { MembersController } from './members/members.controller';
import { MembersService } from './members/members.service';
import { OrganizationsService } from './organizations.service';

/**
 * OrganizationsService is the internal building block registration uses
 * (see AuthService.register). Milestone 11.2 adds the team roster + role
 * management endpoints (MembersController); invites live in their own
 * InvitesModule.
 */
@Module({
  controllers: [MembersController],
  providers: [OrganizationsService, MembersService],
  exports: [OrganizationsService],
})
export class OrganizationsModule {}
