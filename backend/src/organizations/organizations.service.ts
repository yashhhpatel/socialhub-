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
}
