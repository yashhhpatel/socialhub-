import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { InviteStatus, UserRole } from '@prisma/client';

import { InvitesService } from './invites.service';

describe('InvitesService', () => {
  let service: InvitesService;
  let prisma: {
    user: { findUnique: jest.Mock; create: jest.Mock };
    invite: {
      create: jest.Mock;
      findUnique: jest.Mock;
      findMany: jest.Mock;
      update: jest.Mock;
      updateMany: jest.Mock;
    };
    organization: { findUnique: jest.Mock };
    $transaction: jest.Mock;
  };
  let email: { sendInvite: jest.Mock };

  const admin = { userId: 'u_admin', role: UserRole.admin };

  beforeEach(() => {
    prisma = {
      user: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn() },
      invite: {
        create: jest.fn((args) => ({ id: 'inv_1', ...args.data })),
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      organization: { findUnique: jest.fn().mockResolvedValue({ id: 'org_1', name: 'Acme' }) },
      $transaction: jest.fn(async (cb) =>
        cb({
          invite: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
          user: { create: jest.fn((args) => ({ id: 'u_new', ...args.data })) },
        }),
      ),
    };
    email = { sendInvite: jest.fn().mockResolvedValue(undefined) };
    const config = { get: jest.fn().mockReturnValue(undefined) };

    service = new InvitesService(
      prisma as never,
      email as never,
      config as never,
      { assertCanAddTeamMember: jest.fn().mockResolvedValue(undefined) } as never,
      { notifySafe: jest.fn().mockResolvedValue(undefined) } as never,
    );
  });

  describe('create', () => {
    it('persists only a token HASH and emails the accept link', async () => {
      await service.create('org_1', admin, { email: 'New@Ex.com', role: UserRole.editor });

      const data = prisma.invite.create.mock.calls[0][0].data;
      expect(data.email).toBe('new@ex.com'); // normalized
      expect(data.role).toBe(UserRole.editor);
      expect(data.tokenHash).toMatch(/^[0-9a-f]{64}$/); // sha256 hex, not a raw token
      expect(data.tokenHash).not.toContain(' ');
      expect(email.sendInvite).toHaveBeenCalledTimes(1);
      // The raw token goes to the email, never persisted.
      const emailedUrl = email.sendInvite.mock.calls[0][0].inviteUrl as string;
      expect(emailedUrl).toContain('/accept');
    });

    it('refuses to invite an owner', async () => {
      await expect(
        service.create('org_1', admin, { email: 'x@e.com', role: UserRole.owner }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('forbids inviting to a role higher than the inviter', async () => {
      const editor = { userId: 'u_ed', role: UserRole.editor };
      await expect(
        service.create('org_1', editor, { email: 'x@e.com', role: UserRole.admin }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('rejects inviting someone already in the org', async () => {
      prisma.user.findUnique.mockResolvedValue({ email: 'x@e.com', orgId: 'org_1' });
      await expect(
        service.create('org_1', admin, { email: 'x@e.com', role: UserRole.editor }),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('supersedes any outstanding pending invite for the same email', async () => {
      await service.create('org_1', admin, { email: 'x@e.com', role: UserRole.editor });
      expect(prisma.invite.updateMany).toHaveBeenCalledWith({
        where: { orgId: 'org_1', email: 'x@e.com', status: InviteStatus.pending },
        data: { status: InviteStatus.revoked },
      });
    });
  });

  describe('accept', () => {
    const pendingInvite = {
      id: 'inv_1',
      orgId: 'org_1',
      email: 'new@ex.com',
      role: UserRole.editor,
      status: InviteStatus.pending,
      expiresAt: new Date(Date.now() + 60_000),
    };

    it('creates a scoped user at the invited role and claims the invite atomically', async () => {
      prisma.invite.findUnique.mockResolvedValue(pendingInvite);

      const user = await service.accept('rawtoken', { password: 'password123' });

      expect(user.orgId).toBe('org_1');
      expect(user.role).toBe(UserRole.editor);
      expect(user.email).toBe('new@ex.com');
      // The password was hashed, never stored raw.
      expect(user.passwordHash).not.toBe('password123');
      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    });

    it('rejects an unknown or already-used token', async () => {
      prisma.invite.findUnique.mockResolvedValue(null);
      await expect(service.accept('bad', { password: 'password123' })).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('rejects an expired invite', async () => {
      prisma.invite.findUnique.mockResolvedValue({
        ...pendingInvite,
        expiresAt: new Date(Date.now() - 1000),
      });
      await expect(service.accept('t', { password: 'password123' })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects when an account already exists for the invite email', async () => {
      prisma.invite.findUnique.mockResolvedValue(pendingInvite);
      prisma.user.findUnique.mockResolvedValue({ id: 'existing' });
      await expect(service.accept('t', { password: 'password123' })).rejects.toBeInstanceOf(
        ConflictException,
      );
    });
  });

  describe('revoke', () => {
    it('404s an invite from another org', async () => {
      prisma.invite.findUnique.mockResolvedValue({ id: 'inv_1', orgId: 'other' });
      await expect(service.revoke('inv_1', 'org_1')).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
