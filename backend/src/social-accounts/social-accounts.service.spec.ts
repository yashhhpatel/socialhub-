import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'crypto';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { InstagramAdapter } from './adapters/instagram.adapter';
import { SocialAccountsService } from './social-accounts.service';

describe('SocialAccountsService', () => {
  let service: SocialAccountsService;
  let tokenEncryption: TokenEncryptionService;
  let prisma: { socialAccount: { upsert: jest.Mock } };
  let instagramAdapter: { connect: jest.Mock; getAuthorizationUrl: jest.Mock };

  beforeEach(() => {
    // Generated programmatically — never hand-typed, per the lesson from
    // Milestone 2.1's test-fixture mistakes.
    const testKey = randomBytes(32).toString('hex');
    const configService = {
      getOrThrow: jest.fn().mockReturnValue(testKey),
    } as unknown as ConfigService;
    tokenEncryption = new TokenEncryptionService(configService);

    prisma = { socialAccount: { upsert: jest.fn() } };
    instagramAdapter = {
      connect: jest.fn(),
      getAuthorizationUrl: jest.fn().mockReturnValue('https://www.instagram.com/oauth/authorize?mock=1'),
    };

    service = new SocialAccountsService(
      prisma as never,
      tokenEncryption,
      instagramAdapter as unknown as InstagramAdapter,
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
      // Build a real state the same way buildInstagramAuthorizationUrl would.
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
      // Token must never be stored raw — must differ from the plaintext,
      // and must actually decrypt back to it.
      expect(upsertArgs.create.accessTokenEnc).not.toBe('raw_access_token');
      expect(tokenEncryption.decrypt(upsertArgs.create.accessTokenEnc)).toBe(
        'raw_access_token',
      );
    });

    it('rejects a tampered state parameter', async () => {
      service.buildInstagramAuthorizationUrl('org_abc');
      const state = instagramAdapter.getAuthorizationUrl.mock.calls[0][0] as string;
      const tampered = `${state.slice(0, -2)}zz`; // corrupt the end of the base64 payload

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
});
