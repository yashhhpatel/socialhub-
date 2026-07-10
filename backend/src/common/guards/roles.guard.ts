import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { ROLES_KEY } from '../decorators/roles.decorator';
import { roleMeetsMinimum } from '../constants/role-rank';

interface AuthenticatedRequest extends Request {
  user?: { userId: string; email: string; role: UserRole; orgId: string };
}

/**
 * Enforces the minimum role set by @Roles(...) on a route.
 *
 * Scaffold only in this milestone: the decorator/guard pair exists and is
 * unit-tested, but is NOT yet attached to any real endpoint. Per the
 * blueprint, RBAC enforcement is swept across all mutating endpoints in
 * Milestone 11.2, once team invites (11.1) make multi-user orgs with
 * differing roles an actual scenario worth guarding against. Attaching it
 * piecemeal now, to routes with only ever one user (the owner) hitting
 * them, would just be unverifiable-by-testing scaffolding dressed up as
 * enforcement.
 *
 * MUST run after JwtAuthGuard (e.g. @UseGuards(JwtAuthGuard, RolesGuard)):
 * it reads `request.user`, which only JwtAuthGuard's strategy populates.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRole = this.reflector.getAllAndOverride<UserRole | undefined>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    // No @Roles() on this route at all => no restriction from this guard.
    if (!requiredRole) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const user = request.user;

    // No user on the request means JwtAuthGuard didn't run first, or
    // somehow let an unauthenticated request through — fail closed.
    if (!user) {
      return false;
    }

    return roleMeetsMinimum(user.role, requiredRole);
  }
}
