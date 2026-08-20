import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

import { PrismaService } from '../prisma/prisma.service';
import { AccountDataService } from './account-data.service';

describe('AccountDataService', () => {
  let service: AccountDataService;
  let prisma: {
    user: { findUnique: jest.Mock; deleteMany: jest.Mock; delete: jest.Mock };
    organization: { delete: jest.Mock };
    socialAccount: { findMany: jest.Mock; deleteMany: jest.Mock };
    contentAsset: { findMany: jest.Mock; deleteMany: jest.Mock };
    template: { findMany: jest.Mock; deleteMany: jest.Mock };
    comment: { findMany: jest.Mock; deleteMany: jest.Mock };
    brandKit: { deleteMany: jest.Mock };
    aIUsageLog: { deleteMany: jest.Mock };
    auditLog: { deleteMany: jest.Mock };
    invite: { deleteMany: jest.Mock };
    ssoConfig: { deleteMany: jest.Mock };
    $transaction: jest.Mock;
  };
  // Records the order of tx operations so we can assert dependency ordering.
  let opLog: string[];

  beforeEach(() => {
    opLog = [];
    const rec = (name: string) =>
      jest.fn(async (arg?: unknown) => {
        opLog.push(name);
        return { count: 0, ...(typeof arg === 'object' ? {} : {}) };
      });

    prisma = {
      user: {
        findUnique: jest.fn(),
        deleteMany: rec('user.deleteMany'),
        delete: rec('user.delete'),
      },
      organization: { delete: rec('organization.delete') },
      socialAccount: { findMany: jest.fn(), deleteMany: rec('socialAccount.deleteMany') },
      contentAsset: { findMany: jest.fn(), deleteMany: rec('contentAsset.deleteMany') },
      template: { findMany: jest.fn(), deleteMany: rec('template.deleteMany') },
      comment: { findMany: jest.fn(), deleteMany: rec('comment.deleteMany') },
      brandKit: { deleteMany: rec('brandKit.deleteMany') },
      aIUsageLog: { deleteMany: rec('aIUsageLog.deleteMany') },
      auditLog: { deleteMany: rec('auditLog.deleteMany') },
      invite: { deleteMany: rec('invite.deleteMany') },
      ssoConfig: { deleteMany: rec('ssoConfig.deleteMany') },
      // Run the callback against this same mock so ops are recorded in order.
      $transaction: jest.fn(async (fn) => fn(prisma)),
    };

    service = new AccountDataService(prisma as unknown as PrismaService);
  });

  const fakeUser = (over: Record<string, unknown> = {}) => ({
    id: 'u1',
    email: 'jane@example.com',
    role: UserRole.owner,
    orgId: 'org_1',
    passwordHash: 'hash',
    emailVerifiedAt: null,
    mfaEnabled: false,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    ...over,
  });

  describe('exportData', () => {
    it('returns a snapshot without tokens/secrets', async () => {
      prisma.user.findUnique.mockResolvedValue({
        ...fakeUser(),
        organization: {
          id: 'org_1',
          name: 'Acme',
          planTier: 'free',
          createdAt: new Date(),
        },
      });
      prisma.socialAccount.findMany.mockResolvedValue([
        { id: 's1', platform: 'facebook', externalAccountId: 'p1', status: 'connected' },
      ]);
      prisma.contentAsset.findMany.mockResolvedValue([{ id: 'a1' }]);
      prisma.template.findMany.mockResolvedValue([{ id: 't1' }]);
      prisma.comment.findMany.mockResolvedValue([{ id: 'c1', body: 'hi' }]);

      const data = await service.exportData('u1');

      expect(data.account).toMatchObject({ email: 'jane@example.com' });
      expect(data.organization).toMatchObject({ name: 'Acme' });
      expect(data).toHaveProperty('connectedAccounts');
      expect(data).toHaveProperty('designs');
      // The socialAccount query must never select the encrypted token columns.
      const selectArg = prisma.socialAccount.findMany.mock.calls[0][0].select;
      expect(selectArg.accessTokenEnc).toBeUndefined();
      expect(selectArg.refreshTokenEnc).toBeUndefined();
      // And nothing serialised carries a password hash.
      expect(JSON.stringify(data)).not.toContain('passwordHash');
      expect(JSON.stringify(data)).not.toContain('hash');
    });

    it('rejects an unknown user', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      await expect(service.exportData('ghost')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('deleteAccount', () => {
    it('rejects a wrong password without deleting anything', async () => {
      prisma.user.findUnique.mockResolvedValue(fakeUser());
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(false as never);

      await expect(service.deleteAccount('u1', 'wrong')).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('an owner deletes the whole org, children before parents', async () => {
      prisma.user.findUnique.mockResolvedValue(fakeUser({ role: UserRole.owner }));
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(true as never);

      const result = await service.deleteAccount('u1', 'right');

      expect(result).toEqual({ scope: 'organization' });
      // ContentAssets before SocialAccounts (PublishJob→SocialAccount is Restrict).
      expect(opLog.indexOf('contentAsset.deleteMany')).toBeLessThan(
        opLog.indexOf('socialAccount.deleteMany'),
      );
      // Users before the org, and after content/comments.
      expect(opLog.indexOf('user.deleteMany')).toBeLessThan(
        opLog.indexOf('organization.delete'),
      );
      expect(opLog.indexOf('contentAsset.deleteMany')).toBeLessThan(
        opLog.indexOf('user.deleteMany'),
      );
      // The org delete is the final step.
      expect(opLog[opLog.length - 1]).toBe('organization.delete');
      // Every org-FK table is cleared.
      for (const op of [
        'template.deleteMany',
        'brandKit.deleteMany',
        'aIUsageLog.deleteMany',
        'invite.deleteMany',
        'ssoConfig.deleteMany',
      ]) {
        expect(opLog).toContain(op);
      }
    });

    it('a member deletes only their own data, org untouched', async () => {
      prisma.user.findUnique.mockResolvedValue(fakeUser({ role: UserRole.editor }));
      jest.spyOn(bcrypt, 'compare').mockResolvedValue(true as never);

      const result = await service.deleteAccount('u1', 'right');

      expect(result).toEqual({ scope: 'user' });
      // Comments + their designs first (both Restrict → User), then the user.
      expect(opLog).toEqual([
        'comment.deleteMany',
        'contentAsset.deleteMany',
        'user.delete',
      ]);
      // The organization itself is never touched for a member.
      expect(prisma.organization.delete).not.toHaveBeenCalled();
      expect(prisma.user.deleteMany).not.toHaveBeenCalled();
    });
  });
});
