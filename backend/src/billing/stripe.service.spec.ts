import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';

import { StripeService } from './stripe.service';

function makeService(env: Record<string, string> = {}): StripeService {
  const config = {
    get: jest.fn((k: string) => env[k]),
    getOrThrow: jest.fn((k: string) => {
      if (!(k in env)) throw new Error(`missing ${k}`);
      return env[k];
    }),
  } as unknown as ConfigService;
  return new StripeService(config);
}

/// Builds a valid Stripe-Signature header for a payload.
function sign(payload: string, secret: string, t = 1700000000): string {
  const v1 = createHmac('sha256', secret).update(`${t}.${payload}`).digest('hex');
  return `t=${t},v1=${v1}`;
}

describe('StripeService', () => {
  describe('enabled', () => {
    it('is false without a secret key, true with one', () => {
      expect(makeService().enabled).toBe(false);
      expect(makeService({ STRIPE_SECRET_KEY: 'sk_test_x' }).enabled).toBe(true);
    });
  });

  describe('verifyWebhook', () => {
    const secret = 'whsec_test';
    const payload = '{"type":"invoice.paid","id":"evt_1"}';

    it('accepts a correctly signed payload and returns the parsed event', () => {
      const svc = makeService({ STRIPE_WEBHOOK_SECRET: secret });
      const event = svc.verifyWebhook(payload, sign(payload, secret));
      expect(event).toMatchObject({ type: 'invoice.paid', id: 'evt_1' });
    });

    it('rejects a tampered payload', () => {
      const svc = makeService({ STRIPE_WEBHOOK_SECRET: secret });
      const header = sign(payload, secret);
      expect(svc.verifyWebhook(payload + 'x', header)).toBeNull();
    });

    it('rejects a signature made with the wrong secret', () => {
      const svc = makeService({ STRIPE_WEBHOOK_SECRET: secret });
      expect(svc.verifyWebhook(payload, sign(payload, 'wrong'))).toBeNull();
    });

    it('rejects when no webhook secret is configured', () => {
      const svc = makeService();
      expect(svc.verifyWebhook(payload, sign(payload, secret))).toBeNull();
    });

    it('rejects a malformed signature header', () => {
      const svc = makeService({ STRIPE_WEBHOOK_SECRET: secret });
      expect(svc.verifyWebhook(payload, 'garbage')).toBeNull();
    });
  });
});
