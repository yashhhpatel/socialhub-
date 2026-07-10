import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';

import { RolesGuard } from './roles.guard';

function makeContext(user: { role: UserRole } | undefined): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ user }),
    }),
    getHandler: () => ({}),
    getClass: () => ({}),
  } as unknown as ExecutionContext;
}

describe('RolesGuard', () => {
  function guardWithRequiredRole(role: UserRole | undefined) {
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue(role),
    } as unknown as Reflector;
    return new RolesGuard(reflector);
  }

  it('allows access when no @Roles() is set on the route', () => {
    const guard = guardWithRequiredRole(undefined);
    expect(guard.canActivate(makeContext({ role: 'viewer' }))).toBe(true);
  });

  it('denies access when there is no authenticated user on the request', () => {
    const guard = guardWithRequiredRole('admin');
    expect(guard.canActivate(makeContext(undefined))).toBe(false);
  });

  it('denies a lower-ranked role', () => {
    const guard = guardWithRequiredRole('admin');
    expect(guard.canActivate(makeContext({ role: 'editor' }))).toBe(false);
  });

  it('allows an exactly-matching role', () => {
    const guard = guardWithRequiredRole('admin');
    expect(guard.canActivate(makeContext({ role: 'admin' }))).toBe(true);
  });

  it('allows a higher-ranked role ("admin+" includes owner)', () => {
    const guard = guardWithRequiredRole('admin');
    expect(guard.canActivate(makeContext({ role: 'owner' }))).toBe(true);
  });

  it('viewer meets a viewer minimum but nothing above it', () => {
    const guard = guardWithRequiredRole('viewer');
    expect(guard.canActivate(makeContext({ role: 'viewer' }))).toBe(true);
    expect(guard.canActivate(makeContext({ role: 'editor' }))).toBe(true);
  });
});
