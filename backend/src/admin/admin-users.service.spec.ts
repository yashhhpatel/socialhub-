import { NotFoundException } from '@nestjs/common';

import { AccountService } from '../auth/account.service';
import { PrismaService } from '../prisma/prisma.service';
import { AdminUsersService } from './admin-users.service';

describe('AdminUsersService', () => {
  let service: AdminUsersService;
  let prisma: { user: { count: jest.Mock; findMany: jest.Mock; findUnique: jest.Mock } };
  let account: { sendVerificationEmail: jest.Mock; requestPasswordReset: jest.Mock };

  const row = {
    id: 'u1',
    email: 'a@b.com',
    role: 'owner',
    orgId: 'o1',
    emailVerifiedAt: new Date(),
    mfaEnabled: false,
    isPlatformAdmin: false,
    googleId: 'g1',
    passwordHash: null,
    createdAt: new Date(0),
    organization: { name: 'Acme' },
  };

  beforeEach(() => {
    prisma = { user: { count: jest.fn(), findMany: jest.fn(), findUnique: jest.fn() } };
    account = {
      sendVerificationEmail: jest.fn().mockResolvedValue(undefined),
      requestPasswordReset: jest.fn().mockResolvedValue(undefined),
    };
    service = new AdminUsersService(
      prisma as unknown as PrismaService,
      account as unknown as AccountService,
    );
  });

  it('lists users and derives sign-in method without leaking secrets', async () => {
    prisma.user.count.mockResolvedValue(1);
    prisma.user.findMany.mockResolvedValue([row]);

    const res = await service.list({ search: 'A@B' });

    const item = res.data[0];
    expect(item.hasGoogle).toBe(true);
    expect(item.hasPassword).toBe(false);
    expect(item.orgName).toBe('Acme');
    // Neither the googleId value nor passwordHash is ever returned.
    expect(JSON.stringify(item)).not.toMatch(/g1|passwordHash|googleId/);
    // Search is lower-cased.
    expect(prisma.user.findMany.mock.calls[0][0].where.email.contains).toBe('a@b');
  });

  it('detail 404s for an unknown user', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(service.detail('nope')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('resendVerification reuses AccountService', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com' });
    await service.resendVerification('u1');
    expect(account.sendVerificationEmail).toHaveBeenCalledWith('u1', 'a@b.com');
  });

  it('forcePasswordReset reuses AccountService (by email)', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com' });
    await service.forcePasswordReset('u1');
    expect(account.requestPasswordReset).toHaveBeenCalledWith('a@b.com');
  });

  it('actions 404 for an unknown user', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(service.resendVerification('x')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(account.sendVerificationEmail).not.toHaveBeenCalled();
  });
});
