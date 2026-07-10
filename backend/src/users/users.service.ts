import { Injectable } from '@nestjs/common';
import { User, UserRole } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({
      where: { email: email.trim().toLowerCase() },
    });
  }

  findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  /**
   * Creates a user within an EXISTING organization (e.g. the future
   * invite-acceptance flow in Milestone 11.1). NOT used by registration —
   * AuthService.register creates the Organization and its owning User
   * together in a single Prisma transaction, since that's an atomic
   * "both or neither" operation this method (backed by the plain,
   * non-transactional PrismaService) can't safely express on its own.
   */
  create(params: {
    email: string;
    passwordHash: string;
    orgId: string;
    role: UserRole;
  }): Promise<User> {
    return this.prisma.user.create({
      data: {
        email: params.email.trim().toLowerCase(),
        passwordHash: params.passwordHash,
        orgId: params.orgId,
        role: params.role,
      },
    });
  }
}
