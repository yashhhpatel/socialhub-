import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { User, UserRole } from '@prisma/client';

import { roleMeetsMinimum } from '../../common/constants/role-rank';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Org membership management (Milestone 11.2). The team roster and role
 * changes — the enforcement side of RBAC that the invite flow (11.1) feeds.
 */
@Injectable()
export class MembersService {
  constructor(private readonly prisma: PrismaService) {}

  /** Everyone in the org, for the team screen. */
  list(orgId: string): Promise<User[]> {
    return this.prisma.user.findMany({
      where: { orgId },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Changes a member's role, with the guards that keep the hierarchy sound:
   *   - the target must be in the actor's org;
   *   - nobody can be set TO owner, and the owner's role can't be changed
   *     (ownership transfer is a separate, deliberate action);
   *   - you can't act on yourself (no self-promotion or self-lockout);
   *   - you can't assign a role above your own rank, nor change a member who
   *     already outranks you.
   */
  async changeRole(
    orgId: string,
    targetUserId: string,
    newRole: UserRole,
    actor: { userId: string; role: UserRole },
  ): Promise<User> {
    if (targetUserId === actor.userId) {
      throw new BadRequestException('You cannot change your own role.');
    }
    if (newRole === UserRole.owner) {
      throw new BadRequestException('Ownership cannot be assigned via a role change.');
    }

    const target = await this.prisma.user.findUnique({ where: { id: targetUserId } });
    // Same 404 for missing or another org's — never confirm a user exists
    // outside the caller's tenant.
    if (!target || target.orgId !== orgId) {
      throw new NotFoundException('Member not found.');
    }
    if (target.role === UserRole.owner) {
      throw new ForbiddenException("The owner's role cannot be changed.");
    }
    // An admin can manage peers and below, but not someone who outranks them.
    if (!roleMeetsMinimum(actor.role, target.role)) {
      throw new ForbiddenException('You cannot change the role of a member who outranks you.');
    }
    if (!roleMeetsMinimum(actor.role, newRole)) {
      throw new ForbiddenException('You cannot assign a role higher than your own.');
    }

    return this.prisma.user.update({
      where: { id: targetUserId },
      data: { role: newRole },
    });
  }
}
