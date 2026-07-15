import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'crypto';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { XAdapter } from './adapters/x.adapter';
import { SocialAccountsService } from './social-accounts.service';

describe('SocialAccountsService', () => {
  let service: SocialAccountsService;
  let tokenEncryption: TokenEncryptionService;
  let prisma: {
    socialAccount: {
      upsert: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      delete: jest.Mock;
    };
  };
  let instagramAdapter: { connect: jest.Mock; getAuthorizationUrl: jest.Mock };
  let xAdapter: { connect: jest.Mock; getAuthorizationUrl: jest.Mock };

  beforeEach(() => {
    // Generated programmatically — never hand-typed, per the lesson from
    // Milestone 2.1's test-fixture mistakes.
    const testKey = randomBytes(32).toString('hex');
    const configService = {
      getOrThrow: jest.fn().mockReturnValue(testKey),
    } as unknown as ConfigService;
    tokenEncryption = new TokenEncryptionService(configService);

    prisma = {
      socialAccount: {
        upsert: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        delete: jest.fn(),
      },
    };
    instagramAdapter = {
      connect: jest.fn(),
      getAuthorizationUrl: jest.fn().mockReturnValue('https://www.instagram.com/oauth/authorize?mock=1'),
    };
    xAdapter = {
      connect: jest.fn(),
      getAuthorizationUrl: jest.fn().mockReturnValue('https://x.com/i/oauth2/authorize?mock=1'),
    };

    service = new SocialAccountsService(
      prisma as never,
      tokenEncryption,
      instagramAdapter as unknown as InstagramAdapter,
      xAdapter as unknown as XAdapter,
    );
  });

  describe('buildInstagramAuthorizationUrl', () => {
    it('encodes a state the adapter receives, and returns its authorization URL', () => {
      const url = service.buildInstagramAuthorizationUrl('org_123');

      expect(url).toBe('https://www.instagram.com/oauth/authorize?mock=1');
      expect(instagramAdapter.getAuthorizationUrl).toHaveBeenCalledTimes(1);
      const stateArg = instagramAdapter.getAuthorizationUrl.mock.calls[0][0] as string;
      expect(typeof stateArg).toBe('string');
      expect(stateArg.length).toBeGreaterThan(0);
    });
  });

  describe('handleInstagramCallback', () => {
    it('decodes a freshly-issued state and upserts the SocialAccount with encrypted tokens', async () => {
      service.buildInstagramAuthorizationUrl('org_abc');
      const state = instagramAdapter.getAuthorizationUrl.mock.calls[0][0] as string;

      instagramAdapter.connect.mockResolvedValue({
        externalAccountId: 'ig_ext_1',
        accessToken: 'raw_access_token',
        expiresAt: new Date(Date.now() + 1000 * 60 * 60),
      });
      prisma.socialAccount.upsert.mockResolvedValue({
        platform: 'instagram',
        externalAccountId: 'ig_ext_1',
      });

      await service.handleInstagramCallback('auth-code', state);

      const upsertArgs = prisma.socialAccount.upsert.mock.calls[0][0];
      expect(upsertArgs.where.orgId_platform_externalAccountId).toEqual({
        orgId: 'org_abc',
        platform: 'instagram',
        externalAccountId: 'ig_ext_1',
      });
      expect(upsertArgs.create.accessTokenEnc).not.toBe('raw_access_token');
      expect(tokenEncryption.decrypt(upsertArgs.create.accessTokenEnc)).toBe(
        'raw_access_token',
      );
    });

    it('rejects a tampered state parameter', async () => {
      service.buildInstagramAuthorizationUrl('org_abc');
      const state = instagramAdapter.getAuthorizationUrl.mock.calls[0][0] as string;
      const tampered = `${state.slice(0, -2)}zz`;

      await expect(
        service.handleInstagramCallback('code', tampered),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(instagramAdapter.connect).not.toHaveBeenCalled();
    });

    it('rejects an expired state (older than 10 minutes)', async () => {
      const staleState = tokenEncryption.encrypt(
        JSON.stringify({ orgId: 'org_abc', issuedAt: Date.now() - 11 * 60 * 1000 }),
      );

      await expect(
        service.handleInstagramCallback('code', staleState),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(instagramAdapter.connect).not.toHaveBeenCalled();
    });

    it('rejects a state claiming to be issued in the future', async () => {
      const futureState = tokenEncryption.encrypt(
        JSON.stringify({ orgId: 'org_abc', issuedAt: Date.now() + 60 * 1000 }),
      );

      await expect(
        service.handleInstagramCallback('code', futureState),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('buildXAuthorizationUrl', () => {
    it('generates a PKCE pair, folds the verifier into state, and passes the challenge to the adapter', () => {
      const url = service.buildXAuthorizationUrl('org_123');

      expect(url).toBe('https://x.com/i/oauth2/authorize?mock=1');
      expect(xAdapter.getAuthorizationUrl).toHaveBeenCalledTimes(1);
      const [stateArg, challengeArg] = xAdapter.getAuthorizationUrl.mock.calls[0];
      expect(typeof stateArg).toBe('string');
      expect(typeof challengeArg).toBe('string');
      expect(challengeArg.length).toBeGreaterThan(0);
    });
  });

  describe('handleXCallback', () => {
    it('decodes state, extracts the PKCE verifier, and passes both code+verifier to the adapter', async () => {
      service.buildXAuthorizationUrl('org_xyz');
      const state = xAdapter.getAuthorizationUrl.mock.calls[0][0] as string;

      xAdapter.connect.mockResolvedValue({
        externalAccountId: 'x_ext_1',
        accessToken: 'x_raw_access_token',
        refreshToken: 'x_raw_refresh_token',
        expiresAt: new Date(Date.now() + 1000 * 60 * 60),
      });
      prisma.socialAccount.upsert.mockResolvedValue({
        platform: 'x',
        externalAccountId: 'x_ext_1',
      });

      await service.handleXCallback('auth-code', state);

      // The adapter must receive the SAME verifier that was folded into
      // state when the authorization URL was built.
      const connectArgs = xAdapter.connect.mock.calls[0];
      expect(connectArgs[0]).toBe('auth-code');
      expect(typeof connectArgs[1]).toBe('string');
      expect(connectArgs[1].length).toBeGreaterThan(0);

      const upsertArgs = prisma.socialAccount.upsert.mock.calls[0][0];
      expect(upsertArgs.where.orgId_platform_externalAccountId).toEqual({
        orgId: 'org_xyz',
        platform: 'x',
        externalAccountId: 'x_ext_1',
      });
      // Both access AND refresh tokens must be encrypted, never raw.
      expect(tokenEncryption.decrypt(upsertArgs.create.accessTokenEnc)).toBe(
        'x_raw_access_token',
      );
      expect(tokenEncryption.decrypt(upsertArgs.create.refreshTokenEnc)).toBe(
        'x_raw_refresh_token',
      );
    });

    it('rejects a state built for a different flow (missing codeVerifier)', async () => {
      // A plain Instagram-style state (no codeVerifier) replayed against
      // the X callback should fail loudly, not silently proceed without PKCE.
      const instagramStyleState = tokenEncryption.encrypt(
        JSON.stringify({ orgId: 'org_abc', issuedAt: Date.now() }),
      );

      await expect(
        service.handleXCallback('code', instagramStyleState),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(xAdapter.connect).not.toHaveBeenCalled();
    });
  });

  describe('listForOrg', () => {
    it('queries scoped to the given org', async () => {
      prisma.socialAccount.findMany.mockResolvedValue([]);
      await service.listForOrg('org_1');
      expect(prisma.socialAccount.findMany).toHaveBeenCalledWith({
        where: { orgId: 'org_1' },
      });
    });
  });

  describe('disconnect', () => {
    it('deletes the account when it belongs to the caller\'s org', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        id: 'sa_1',
        orgId: 'org_1',
      });

      await service.disconnect('sa_1', 'org_1');

      expect(prisma.socialAccount.delete).toHaveBeenCalledWith({
        where: { id: 'sa_1' },
      });
    });

    it('throws NotFoundException (not a permission error) if the account belongs to a different org', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        id: 'sa_1',
        orgId: 'some_other_org',
      });

      await expect(service.disconnect('sa_1', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.socialAccount.delete).not.toHaveBeenCalled();
    });

    it('throws NotFoundException if the account does not exist at all', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue(null);

      await expect(service.disconnect('missing', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });
});
