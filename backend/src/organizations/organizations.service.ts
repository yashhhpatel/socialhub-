import { Injectable } from '@nestjs/common';
import { Organization } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OrganizationsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Standalone org creation (no owner assignment). Used by any future
   * flow that creates an org outside of registration.
   *
   * NOTE: registration's org+owner creation does NOT go through this
   * method — see AuthService.register, which creates both records in a
   * single Prisma transaction instead. This service's `this.prisma` is
   * the plain (non-transactional) client, so composing it into another
   * service's transaction isn't possible without passing a transaction
   * client through as a parameter — deferred until a second real use case
   * actually needs that, rather than generalizing for a hypothetical one.
   */
  create(name: string): Promise<Organization> {
    return this.prisma.organization.create({ data: { name } });
  }

  findById(id: string): Promise<Organization | null> {
    return this.prisma.organization.findUnique({ where: { id } });
  }

  /**
   * Org overview for the Organizations settings page: name, plan, approval
   * policy, and how many members it has. One extra count query alongside the
   * org read.
   */
  async overview(id: string): Promise<{
    id: string;
    name: string;
    planTier: string;
    requiresApproval: boolean;
    memberCount: number;
  } | null> {
    const org = await this.prisma.organization.findUnique({ where: { id } });
    if (!org) return null;
    const memberCount = await this.prisma.user.count({ where: { orgId: id } });
    return {
      id: org.id,
      name: org.name,
      planTier: org.planTier,
      requiresApproval: org.requiresApproval,
      memberCount,
    };
  }
}
