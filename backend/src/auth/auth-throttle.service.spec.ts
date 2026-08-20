import { HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Redis } from 'ioredis';

import { AuthThrottleService } from './auth-throttle.service';

/** Minimal in-memory Redis double covering the ops the service uses. */
class FakeRedis {
  store = new Map<string, number>();
  failing = false;

  async get(key: string): Promise<string | null> {
    if (this.failing) throw new Error('redis down');
    const v = this.store.get(key);
    return v === undefined ? null : String(v);
  }

  async incr(key: string): Promise<number> {
    if (this.failing) throw new Error('redis down');
    const next = (this.store.get(key) ?? 0) + 1;
    this.store.set(key, next);
    return next;
  }

  async expire(key: string, seconds: number): Promise<number> {
    if (this.failing) throw new Error('redis down');
    void key;
    void seconds;
    return 1;
  }

  async del(key: string): Promise<number> {
    if (this.failing) throw new Error('redis down');
    return this.store.delete(key) ? 1 : 0;
  }
}

function makeService(overrides: Record<string, number> = {}) {
  const config = {
    get: jest.fn((key: string, fallback?: number) => overrides[key] ?? fallback),
  } as unknown as ConfigService;
  const redis = new FakeRedis();
  const service = new AuthThrottleService(redis as unknown as Redis, config);
  return { service, redis };
}

function expect429(err: unknown) {
  expect(err).toBeInstanceOf(HttpException);
  expect((err as HttpException).getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
}

describe('AuthThrottleService', () => {
  describe('login lockout', () => {
    it('allows attempts below the per-email threshold and blocks at it', async () => {
      const { service } = makeService({ AUTH_THROTTLE_MAX_PER_EMAIL: 3 });

      // 3 failures recorded.
      for (let i = 0; i < 3; i++) {
        await service.assertLoginAllowed('jane@example.com', '10.0.0.1');
        await service.recordLoginFailure('jane@example.com', '10.0.0.1');
      }

      // The 4th check sees the email counter at the threshold and blocks.
      await service
        .assertLoginAllowed('jane@example.com', '10.0.0.9')
        .then(() => fail('expected lockout'))
        .catch(expect429);
    });

    it('normalizes the email so case/whitespace cannot dodge the counter', async () => {
      const { service } = makeService({ AUTH_THROTTLE_MAX_PER_EMAIL: 2 });

      await service.recordLoginFailure('Jane@Example.com ', '10.0.0.1');
      await service.recordLoginFailure('  jane@example.com', '10.0.0.2');

      await service
        .assertLoginAllowed('JANE@EXAMPLE.COM', '10.0.0.3')
        .then(() => fail('expected lockout'))
        .catch(expect429);
    });

    it('blocks on the per-IP threshold across different emails (credential stuffing)', async () => {
      const { service } = makeService({
        AUTH_THROTTLE_MAX_PER_EMAIL: 999,
        AUTH_THROTTLE_MAX_PER_IP: 3,
      });

      for (let i = 0; i < 3; i++) {
        await service.recordLoginFailure(`user${i}@example.com`, '10.0.0.1');
      }

      await service
        .assertLoginAllowed('another@example.com', '10.0.0.1')
        .then(() => fail('expected lockout'))
        .catch(expect429);
    });

    it('clears the email counter on success', async () => {
      const { service } = makeService({ AUTH_THROTTLE_MAX_PER_EMAIL: 2 });

      await service.recordLoginFailure('jane@example.com', '10.0.0.1');
      await service.recordLoginFailure('jane@example.com', '10.0.0.1');
      await service.recordLoginSuccess('jane@example.com');

      // Counter reset — a fresh check passes.
      await expect(
        service.assertLoginAllowed('jane@example.com', '10.0.0.2'),
      ).resolves.toBeUndefined();
    });

    it('fails open when Redis is unavailable', async () => {
      const { service, redis } = makeService({ AUTH_THROTTLE_MAX_PER_EMAIL: 1 });
      redis.failing = true;

      // Even after "failures", a Redis outage must never block a real user.
      await service.recordLoginFailure('jane@example.com', '10.0.0.1');
      await expect(
        service.assertLoginAllowed('jane@example.com', '10.0.0.1'),
      ).resolves.toBeUndefined();
    });
  });

  describe('assertNotFlooding', () => {
    it('allows up to the flood allowance then blocks', async () => {
      const { service } = makeService({ AUTH_FLOOD_MAX_PER_IP: 2 });

      await expect(
        service.assertNotFlooding('10.0.0.1', 'password-reset'),
      ).resolves.toBeUndefined();
      await expect(
        service.assertNotFlooding('10.0.0.1', 'password-reset'),
      ).resolves.toBeUndefined();

      await service
        .assertNotFlooding('10.0.0.1', 'password-reset')
        .then(() => fail('expected flood block'))
        .catch(expect429);
    });

    it('scopes counters independently per IP', async () => {
      const { service } = makeService({ AUTH_FLOOD_MAX_PER_IP: 1 });

      await expect(
        service.assertNotFlooding('10.0.0.1', 'password-reset'),
      ).resolves.toBeUndefined();
      // A different IP is unaffected by the first IP's count.
      await expect(
        service.assertNotFlooding('10.0.0.2', 'password-reset'),
      ).resolves.toBeUndefined();
    });
  });
});
