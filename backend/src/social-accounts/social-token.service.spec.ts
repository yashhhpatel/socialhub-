import { Platform, SocialAccount, SocialAccountStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import {
  SocialTokenService,
  TokenReconnectRequiredError,
  TOKEN_REFRESH_THRESHOLD_MS,
} from './social-token.service';

function account(over: Partial<SocialAccount> = {}): SocialAccount {
  return {
    id: 'acc1',
    orgId: 'org1',
    platform: Platform.x,
    externalAccountId: 'ext1',
    externalUserId: null,
    accessTokenEnc: 'ENC(access-old)',
    refreshTokenEnc: 'ENC(refresh-old)',
    expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10m → due for refresh
    status: SocialAccountStatus.connected,
    createdAt: new Date(),
    ...over,
  } as SocialAccount;
}

describe('SocialTokenService', () => {
  let prisma: {
    socialAccount: { update: jest.Mock; findMany: jest.Mock };
  };
  let enc: TokenEncryptionService;
  let xAdapter: { refresh: jest.Mock };
  let igAdapter: { refresh: jest.Mock };
  let service: SocialTokenService;

  beforeEach(() => {
    prisma = {
      socialAccount: {
        update: jest.fn(async ({ data }) => ({ ...account(), ...data })),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    enc = {
      encrypt: (v: string) => `ENC(${v})`,
      decrypt: (v: string) => v.replace(/^ENC\(|\)$/g, ''),
    } as unknown as TokenEncryptionService;
    xAdapter = { refresh: jest.fn() };
    igAdapter = { refresh: jest.fn() };
    service = new SocialTokenService(
      prisma as unknown as PrismaService,
      enc,
      igAdapter as never, // instagram
      xAdapter as never, // x
      { refresh: jest.fn() } as never, // facebook
      { refresh: jest.fn() } as never, // threads
      { refresh: jest.fn() } as never, // linkedin
    );
  });

  describe('needsReconnect / isDueForRefresh', () => {
    it('flags every non-connected status as needing reconnect', () => {
      expect(SocialTokenService.needsReconnect(SocialAccountStatus.connected)).toBe(false);
      expect(SocialTokenService.needsReconnect(SocialAccountStatus.expired)).toBe(true);
      expect(SocialTokenService.needsReconnect(SocialAccountStatus.revoked)).toBe(true);
      expect(SocialTokenService.needsReconnect(SocialAccountStatus.error)).toBe(true);
    });

    it('is due only inside the proactive window', () => {
      const now = new Date();
      expect(service.isDueForRefresh(account({ expiresAt: null }), now)).toBe(false);
      expect(
        service.isDueForRefresh(
          account({ expiresAt: new Date(now.getTime() + TOKEN_REFRESH_THRESHOLD_MS + 60_000) }),
          now,
        ),
      ).toBe(false);
      expect(
        service.isDueForRefresh(
          account({ expiresAt: new Date(now.getTime() + 60_000) }),
          now,
        ),
      ).toBe(true);
    });
  });

  describe('ensureFreshAccessToken', () => {
    it('returns the current token without refreshing when not due', async () => {
      const token = await service.ensureFreshAccessToken(
        account({ expiresAt: new Date(Date.now() + 5 * TOKEN_REFRESH_THRESHOLD_MS) }),
      );
      expect(token).toBe('access-old');
      expect(xAdapter.refresh).not.toHaveBeenCalled();
    });

    it('throws reconnect-required for a non-connected account', async () => {
      await expect(
        service.ensureFreshAccessToken(account({ status: SocialAccountStatus.revoked })),
      ).rejects.toBeInstanceOf(TokenReconnectRequiredError);
      expect(xAdapter.refresh).not.toHaveBeenCalled();
    });

    it('refreshes when due and returns the new token', async () => {
      xAdapter.refresh.mockResolvedValue({
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
        expiresAt: new Date(Date.now() + 3600_000),
      });
      const token = await service.ensureFreshAccessToken(account());
      expect(xAdapter.refresh).toHaveBeenCalledWith('refresh-old');
      expect(token).toBe('access-new');
    });
  });

  describe('refreshAccount', () => {
    it('persists rotated tokens, expiry and connected status on success', async () => {
      const expiresAt = new Date(Date.now() + 3600_000);
      xAdapter.refresh.mockResolvedValue({
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
        expiresAt,
      });
      await service.refreshAccount(account());
      expect(prisma.socialAccount.update).toHaveBeenCalledWith({
        where: { id: 'acc1' },
        data: {
          accessTokenEnc: 'ENC(access-new)',
          refreshTokenEnc: 'ENC(refresh-new)',
          expiresAt,
          status: SocialAccountStatus.connected,
        },
      });
    });

    it('keeps the existing refresh token when the platform does not return a new one', async () => {
      // Instagram-style in-place refresh: no refresh token, use access token as input.
      igAdapter.refresh.mockResolvedValue({
        accessToken: 'ig-new',
        expiresAt: new Date(Date.now() + 3600_000),
      });
      await service.refreshAccount(
        account({ platform: Platform.instagram, refreshTokenEnc: null }),
      );
      // input token is the access token (no stored refresh token)
      expect(igAdapter.refresh).toHaveBeenCalledWith('access-old');
      const data = prisma.socialAccount.update.mock.calls[0][0].data;
      expect(data.refreshTokenEnc).toBeNull();
      expect(data.accessTokenEnc).toBe('ENC(ig-new)');
    });

    it('marks the account revoked and throws when refresh is rejected', async () => {
      xAdapter.refresh.mockRejectedValue(new Error('X token refresh failed: 400 invalid_grant'));
      await expect(service.refreshAccount(account())).rejects.toBeInstanceOf(
        TokenReconnectRequiredError,
      );
      expect(prisma.socialAccount.update).toHaveBeenCalledWith({
        where: { id: 'acc1' },
        data: { status: SocialAccountStatus.revoked },
      });
    });

    it('marks expired when a past-expiry token fails to refresh for a non-auth reason', async () => {
      xAdapter.refresh.mockRejectedValue(new Error('network timeout'));
      await expect(
        service.refreshAccount(account({ expiresAt: new Date(Date.now() - 1000) })),
      ).rejects.toBeInstanceOf(TokenReconnectRequiredError);
      expect(prisma.socialAccount.update).toHaveBeenCalledWith({
        where: { id: 'acc1' },
        data: { status: SocialAccountStatus.expired },
      });
    });
  });

  describe('refreshDueAccounts', () => {
    it('refreshes each due account and counts reconnect failures', async () => {
      prisma.socialAccount.findMany.mockResolvedValue([
        account({ id: 'a', platform: Platform.x }),
        account({ id: 'b', platform: Platform.x }),
      ]);
      xAdapter.refresh
        .mockResolvedValueOnce({ accessToken: 'n1', refreshToken: 'r1', expiresAt: new Date() })
        .mockRejectedValueOnce(new Error('invalid_grant'));

      const result = await service.refreshDueAccounts();
      expect(result.due).toBe(2);
      expect(result.refreshed).toBe(1);
      expect(result.needsReconnect).toBe(1);
    });

    it('queries only connected accounts with an expiry inside the window', async () => {
      await service.refreshDueAccounts(new Date(1_000_000));
      const where = prisma.socialAccount.findMany.mock.calls[0][0].where;
      expect(where.status).toBe(SocialAccountStatus.connected);
      expect(where.expiresAt.not).toBeNull();
      expect(where.expiresAt.lte).toEqual(
        new Date(1_000_000 + TOKEN_REFRESH_THRESHOLD_MS),
      );
    });
  });
});
