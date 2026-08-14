import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';

import { MembersService } from './members.service';

describe('MembersService.changeRole', () => {
  let service: MembersService;
  let prisma: { user: { findUnique: jest.Mock; update: jest.Mock; findMany: jest.Mock } };

  const admin = { userId: 'u_admin', role: UserRole.admin };
  const editorTarget = { id: 'u_ed', orgId: 'org_1', role: UserRole.editor };

  beforeEach(() => {
    prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(editorTarget),
        update: jest.fn((args) => ({ ...editorTarget, ...args.data })),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    service = new MembersService(prisma as never);
  });

  it('promotes an editor to admin when the actor is admin', async () => {
    const updated = await service.changeRole('org_1', 'u_ed', UserRole.admin, admin);
    expect(updated.role).toBe(UserRole.admin);
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'u_ed' },
      data: { role: UserRole.admin },
    });
  });

  it('refuses to change your own role', async () => {
    await expect(
      service.changeRole('org_1', 'u_admin', UserRole.editor, admin),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses to assign owner', async () => {
    await expect(
      service.changeRole('org_1', 'u_ed', UserRole.owner, admin),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('404s a member from another org', async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'u_ed', orgId: 'other', role: UserRole.editor });
    await expect(
      service.changeRole('org_1', 'u_ed', UserRole.admin, admin),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it("refuses to change the owner's role", async () => {
    prisma.user.findUnique.mockResolvedValue({ id: 'u_owner', orgId: 'org_1', role: UserRole.owner });
    await expect(
      service.changeRole('org_1', 'u_owner', UserRole.admin, admin),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('refuses to assign a role above the actor rank', async () => {
    const editorActor = { userId: 'u_ed2', role: UserRole.editor };
    // An editor can't promote anyone to admin.
    prisma.user.findUnique.mockResolvedValue({ id: 'u_v', orgId: 'org_1', role: UserRole.viewer });
    await expect(
      service.changeRole('org_1', 'u_v', UserRole.admin, editorActor),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
