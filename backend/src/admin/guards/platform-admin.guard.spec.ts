import {
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';

import { PrismaService } from '../../prisma/prisma.service';
import { PlatformAdminGuard } from './platform-admin.guard';

function ctxFor(user: unknown): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
  } as unknown as ExecutionContext;
}

describe('PlatformAdminGuard', () => {
  let guard: PlatformAdminGuard;
  let prisma: { user: { findUnique: jest.Mock } };

  beforeEach(() => {
    prisma = { user: { findUnique: jest.fn() } };
    guard = new PlatformAdminGuard(prisma as unknown as PrismaService);
  });

  it('allows a platform admin (verified from the DB)', async () => {
    prisma.user.findUnique.mockResolvedValue({ isPlatformAdmin: true });
    await expect(guard.canActivate(ctxFor({ userId: 'u1' }))).resolves.toBe(true);
    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { id: 'u1' },
      select: { isPlatformAdmin: true },
    });
  });

  it('forbids a non-admin (flag false)', async () => {
    prisma.user.findUnique.mockResolvedValue({ isPlatformAdmin: false });
    await expect(guard.canActivate(ctxFor({ userId: 'u1' }))).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('forbids when the user no longer exists (instant revocation on delete)', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(guard.canActivate(ctxFor({ userId: 'u1' }))).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('401s when there is no authenticated user on the request', async () => {
    await expect(guard.canActivate(ctxFor(undefined))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });
});
