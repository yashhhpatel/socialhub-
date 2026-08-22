import { createHmac } from 'crypto';

import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Platform } from '@prisma/client';
import { Request, Response } from 'express';

import { WebhooksController } from './webhooks.controller';
import { WebhooksService } from './webhooks.service';

const IG_SECRET = 'ig-secret';
const VERIFY_TOKEN = 'verify-me';

function fakeRes() {
  const res: Partial<Response> & { body?: unknown; statusCode?: number } = {};
  res.status = jest.fn(function (this: typeof res, code: number) {
    this.statusCode = code;
    return this as Response;
  }) as never;
  res.type = jest.fn(function (this: typeof res) {
    return this as Response;
  }) as never;
  res.send = jest.fn(function (this: typeof res, b: unknown) {
    this.body = b;
    return this as Response;
  }) as never;
  return res as Response & { body?: unknown; statusCode?: number };
}

function reqWith(body: string): Request {
  return { rawBody: Buffer.from(body, 'utf8') } as unknown as Request;
}

function sign(body: string, secret = IG_SECRET): string {
  return 'sha256=' + createHmac('sha256', secret).update(body).digest('hex');
}

describe('WebhooksController', () => {
  let controller: WebhooksController;
  let webhooks: { handleMetaEvent: jest.Mock };

  beforeEach(() => {
    webhooks = { handleMetaEvent: jest.fn().mockResolvedValue({ handled: 1 }) };
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'INSTAGRAM_CLIENT_SECRET') return IG_SECRET;
        if (key === 'META_WEBHOOK_VERIFY_TOKEN') return VERIFY_TOKEN;
        return undefined;
      }),
    };
    controller = new WebhooksController(
      webhooks as unknown as WebhooksService,
      config as unknown as ConfigService,
    );
  });

  describe('GET handshake', () => {
    it('echoes the challenge when mode + verify token match', () => {
      const res = fakeRes();
      controller.verify('instagram', 'subscribe', VERIFY_TOKEN, 'CHALLENGE_42', res);
      expect(res.statusCode).toBe(200);
      expect(res.body).toBe('CHALLENGE_42');
    });

    it('403s on a wrong verify token', () => {
      const res = fakeRes();
      controller.verify('instagram', 'subscribe', 'wrong', 'CHALLENGE_42', res);
      expect(res.statusCode).toBe(403);
      expect(res.body).not.toBe('CHALLENGE_42');
    });

    it('404s an unknown platform', () => {
      expect(() =>
        controller.verify('tiktok', 'subscribe', VERIFY_TOKEN, 'x', fakeRes()),
      ).toThrow(NotFoundException);
    });
  });

  describe('POST delivery', () => {
    const body = JSON.stringify({
      object: 'instagram',
      entry: [{ id: 'u', changes: [] }],
    });

    it('dispatches a correctly-signed event and returns received', async () => {
      const out = await controller.receive('instagram', sign(body), reqWith(body));
      expect(webhooks.handleMetaEvent).toHaveBeenCalledWith(
        Platform.instagram,
        expect.objectContaining({ object: 'instagram' }),
      );
      expect(out).toEqual({ received: true, handled: 1 });
    });

    it('rejects a bad signature with 403 and never dispatches', async () => {
      await expect(
        controller.receive('instagram', sign(body, 'wrong'), reqWith(body)),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(webhooks.handleMetaEvent).not.toHaveBeenCalled();
    });

    it('404s an unknown platform before touching the body', async () => {
      await expect(
        controller.receive('tiktok', sign(body), reqWith(body)),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('acknowledges (200) an authentic but unparseable body without dispatching', async () => {
      const bad = '{not json';
      const out = await controller.receive('instagram', sign(bad), reqWith(bad));
      expect(out).toEqual({ received: true, handled: 0 });
      expect(webhooks.handleMetaEvent).not.toHaveBeenCalled();
    });
  });
});
