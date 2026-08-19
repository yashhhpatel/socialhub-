import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';
import { Request } from 'express';

import { SocialAccountsController } from './social-accounts.controller';
import { SocialAccountsService } from './social-accounts.service';

/** Builds a valid Meta signed_request the way Meta does. */
function sign(payload: Record<string, unknown>, secret: string): string {
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = createHmac('sha256', secret)
    .update(encodedPayload)
    .digest('base64url');
  return `${signature}.${encodedPayload}`;
}

const FB_SECRET = 'facebook-app-secret';

describe('SocialAccountsController — Meta compliance callbacks', () => {
  let controller: SocialAccountsController;
  let service: {
    purgePlatformUser: jest.Mock;
    recordDataDeletion: jest.Mock;
    getDataDeletionStatus: jest.Mock;
  };

  beforeEach(() => {
    service = {
      purgePlatformUser: jest.fn().mockResolvedValue(1),
      recordDataDeletion: jest.fn().mockResolvedValue('confcode123'),
      getDataDeletionStatus: jest.fn(),
    };
    const config = {
      get: jest.fn((key: string) =>
        key === 'FACEBOOK_APP_SECRET' ? FB_SECRET : undefined,
      ),
    } as unknown as ConfigService;

    controller = new SocialAccountsController(
      service as unknown as SocialAccountsService,
      config,
    );
  });

  describe('deauthorize', () => {
    it('verifies the signature and purges the platform user', async () => {
      const signed = sign({ user_id: 'meta_user_1', algorithm: 'HMAC-SHA256' }, FB_SECRET);

      const result = await controller.deauthorize('facebook', signed);

      expect(result).toEqual({ success: true });
      expect(service.purgePlatformUser).toHaveBeenCalledWith('facebook', 'meta_user_1');
    });

    it('rejects a forged signature without touching the service', async () => {
      const forged = sign({ user_id: 'x', algorithm: 'HMAC-SHA256' }, 'wrong-secret');

      await expect(controller.deauthorize('facebook', forged)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(service.purgePlatformUser).not.toHaveBeenCalled();
    });

    it('rejects a non-Meta platform', async () => {
      const signed = sign({ user_id: 'x', algorithm: 'HMAC-SHA256' }, FB_SECRET);

      await expect(controller.deauthorize('linkedin', signed)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects a missing signed_request', async () => {
      await expect(
        controller.deauthorize('facebook', undefined as unknown as string),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('dataDeletion', () => {
    it('records the deletion and returns an absolute status url with the code', async () => {
      const signed = sign({ user_id: 'meta_user_2', algorithm: 'HMAC-SHA256' }, FB_SECRET);
      const req = {
        get: (h: string) => (h === 'host' ? 'example.com' : undefined),
        protocol: 'https',
      } as unknown as Request;

      const result = await controller.dataDeletion('facebook', signed, req);

      expect(service.recordDataDeletion).toHaveBeenCalledWith('facebook', 'meta_user_2');
      expect(result.confirmation_code).toBe('confcode123');
      expect(result.url).toBe(
        'https://example.com/social-accounts/data-deletion/status?code=confcode123',
      );
    });

    it('honours x-forwarded-proto when set (behind a tunnel/proxy)', async () => {
      const signed = sign({ user_id: 'u', algorithm: 'HMAC-SHA256' }, FB_SECRET);
      const req = {
        get: (h: string) =>
          h === 'host' ? 'ngrok.dev' : h === 'x-forwarded-proto' ? 'https' : undefined,
        protocol: 'http',
      } as unknown as Request;

      const result = await controller.dataDeletion('facebook', signed, req);
      expect(result.url.startsWith('https://ngrok.dev/')).toBe(true);
    });
  });

  describe('dataDeletionStatus', () => {
    it('returns the recorded status for a known code', async () => {
      service.getDataDeletionStatus.mockResolvedValue({
        confirmationCode: 'confcode123',
        status: 'completed',
        createdAt: new Date('2026-08-19T00:00:00.000Z'),
      });

      const result = await controller.dataDeletionStatus('confcode123');

      expect(result).toEqual({
        code: 'confcode123',
        status: 'completed',
        completedAt: '2026-08-19T00:00:00.000Z',
      });
    });

    it('returns not_found for an unknown or missing code', async () => {
      service.getDataDeletionStatus.mockResolvedValue(null);

      await expect(controller.dataDeletionStatus('nope')).resolves.toEqual({
        code: 'nope',
        status: 'not_found',
        completedAt: null,
      });
    });
  });
});
