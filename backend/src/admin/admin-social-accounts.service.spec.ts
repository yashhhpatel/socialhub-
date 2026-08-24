import { NotFoundException } from '@nestjs/common';
import { SocialAccountStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  SocialTokenService,
  TokenReconnectRequiredError,
} from '../social-accounts/social-token.service';
import { AdminSocialAccountsService } from './admin-social-accounts.service';

describe('AdminSocialAccountsService', () => {
  let service: AdminSocialAccountsService;
  let prisma: {
    socialAccount: {
      count: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      delete: jest.Mock;
    };
  };
  let tokens: { refreshAccount: jest.Mock };

  beforeEach(() => {
    prisma = {
      socialAccount: {
        count: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        delete: jest.fn(),
      },
    };
    tokens = { refreshAccount: jest.fn() };
    service = new AdminSocialAccountsService(
      prisma as unknown as PrismaService,
      tokens as unknown as SocialTokenService,
    );
  });

  it('lists with a valid status filter and never returns token ciphertext', async () => {
    prisma.socialAccount.count.mockResolvedValue(1);
    prisma.socialAccount.findMany.mockResolvedValue([
      {
        id: 's1',
        orgId: 'o1',
        platform: 'x',
        externalAccountId: 'ext',
        status: 'expired',
        expiresAt: new Date(0),
        createdAt: new Date(0),
        organization: { name: 'Acme' },
      },
    ]);

    const res = await service.list({ status: 'expired' });

    expect(prisma.socialAccount.findMany.mock.calls[0][0].where.status).toBe(
      'expired',
    );
    expect(res.data[0].orgName).toBe('Acme');
    expect(JSON.stringify(res)).not.toMatch(/accessTokenEnc|refreshTokenEnc/);
  });

  it('ignores an invalid status filter', async () => {
    prisma.socialAccount.count.mockResolvedValue(0);
    prisma.socialAccount.findMany.mockResolvedValue([]);
    await service.list({ status: 'bogus' });
    expect(prisma.socialAccount.findMany.mock.calls[0][0].where.status).toBeUndefined();
  });

  it('refresh returns connected on success', async () => {
    prisma.socialAccount.findUnique.mockResolvedValue({ id: 's1' });
    tokens.refreshAccount.mockResolvedValue({ status: 'connected' });
    const res = await service.refresh('s1');
    expect(res).toEqual({ id: 's1', status: 'connected', needsReconnect: false });
  });

  it('refresh reports needsReconnect when the token cannot be refreshed', async () => {
    prisma.socialAccount.findUnique.mockResolvedValue({ id: 's1' });
    tokens.refreshAccount.mockRejectedValue(
      new TokenReconnectRequiredError('x' as never, SocialAccountStatus.revoked),
    );
    const res = await service.refresh('s1');
    expect(res).toEqual({ id: 's1', status: 'revoked', needsReconnect: true });
  });

  it('refresh 404s for an unknown account', async () => {
    prisma.socialAccount.findUnique.mockResolvedValue(null);
    await expect(service.refresh('nope')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('disconnect deletes an existing account', async () => {
    prisma.socialAccount.findUnique.mockResolvedValue({ id: 's1' });
    prisma.socialAccount.delete.mockResolvedValue({});
    await service.disconnect('s1');
    expect(prisma.socialAccount.delete).toHaveBeenCalledWith({ where: { id: 's1' } });
  });
});
