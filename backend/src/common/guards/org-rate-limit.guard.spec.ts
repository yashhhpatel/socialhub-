import { ExecutionContext, HttpException } from '@nestjs/common';

import { OrgRateLimitGuard } from './org-rate-limit.guard';

function ctx(user: { orgId: string } | undefined) {
  const res = { setHeader: jest.fn() };
  return {
    context: {
      switchToHttp: () => ({
        getRequest: () => ({ user }),
        getResponse: () => res,
      }),
    } as unknown as ExecutionContext,
    res,
  };
}

describe('OrgRateLimitGuard', () => {
  let guard: OrgRateLimitGuard;
  let redis: { incr: jest.Mock; expire: jest.Mock };
  const config = { get: (_k: string, d: unknown) => d }; // defaults: 600 / 60s

  beforeEach(() => {
    redis = { incr: jest.fn(), expire: jest.fn().mockResolvedValue(1) };
    guard = new OrgRateLimitGuard(redis as never, config as never);
  });

  it('lets unauthenticated (no-org) requests through untouched', async () => {
    const { context } = ctx(undefined);
    expect(await guard.canActivate(context)).toBe(true);
    expect(redis.incr).not.toHaveBeenCalled();
  });

  it('counts against a per-ORG key (isolation) and sets the TTL on first hit', async () => {
    redis.incr.mockResolvedValue(1);
    const { context } = ctx({ orgId: 'org_1' });

    expect(await guard.canActivate(context)).toBe(true);
    const key = redis.incr.mock.calls[0][0] as string;
    expect(key).toContain('ratelimit:org:org_1:');
    expect(redis.expire).toHaveBeenCalledWith(key, 60);
  });

  it('uses a DIFFERENT key per org, so one org cannot consume another\'s pool', async () => {
    redis.incr.mockResolvedValue(1);
    await guard.canActivate(ctx({ orgId: 'org_a' }).context);
    await guard.canActivate(ctx({ orgId: 'org_b' }).context);

    const keyA = redis.incr.mock.calls[0][0] as string;
    const keyB = redis.incr.mock.calls[1][0] as string;
    expect(keyA).toContain('org_a');
    expect(keyB).toContain('org_b');
    expect(keyA).not.toBe(keyB);
  });

  it('allows up to the limit and rejects once over it', async () => {
    redis.incr.mockResolvedValue(600); // exactly at the default limit
    expect(await guard.canActivate(ctx({ orgId: 'org_1' }).context)).toBe(true);

    redis.incr.mockResolvedValue(601); // over
    const { context, res } = ctx({ orgId: 'org_1' });
    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(HttpException);
    await expect(guard.canActivate(context)).rejects.toMatchObject({ status: 429 });
    expect(res.setHeader).toHaveBeenCalledWith('Retry-After', 60);
  });

  it('fails OPEN when Redis errors — never blocks traffic on a limiter outage', async () => {
    redis.incr.mockRejectedValue(new Error('redis down'));
    expect(await guard.canActivate(ctx({ orgId: 'org_1' }).context)).toBe(true);
  });
});
