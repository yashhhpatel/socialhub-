import { Module } from '@nestjs/common';

import { OrganizationsService } from './organizations.service';

/**
 * No controller yet — this milestone only needs org creation as an
 * internal building block for registration (see AuthService.register).
 * REST endpoints (invite, role management, white-labeling) are added by
 * the specific milestones that need them (11.1, 11.2, 15.4).
 */
@Module({
  providers: [OrganizationsService],
  exports: [OrganizationsService],
})
export class OrganizationsModule {}
