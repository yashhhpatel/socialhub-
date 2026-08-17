import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request, Response } from 'express';
import type { Redis } from 'ioredis';

import { RATE_LIMIT_REDIS } from '../rate-limit/rate-limit.tokens';

interface AuthedRequest extends Request {
  user?: { orgId: string };
}

/**
 * Per-organization rate limiting (Milestone 15.3).
 *
 * Each org gets its OWN Redis counter (`ratelimit:org:<id>:<window>`), so one
 * org burning through its allowance can never throttle another — the pool is
 * dedicated per tenant, which is the whole point. A simple fixed-window
 * counter (INCR + first-hit EXPIRE) is enough for tenant isolation and is
 * cheap on the hot path.
 *
 * Only authenticated, org-scoped requests are limited; pre-auth routes
 * (login/register/SSO) and health carry no org and pass through.
 *
 * FAILS OPEN: if Redis is unreachable the request is allowed, not blocked —
 * a limiter outage must degrade to "no limiting", never to "everything 500s".
 */
@Injectable()
export class OrgRateLimitGuard implements CanActivate {
  private readonly logger = new Logger(OrgRateLimitGuard.name);

  constructor(
    @Inject(RATE_LIMIT_REDIS) private readonly redis: Redis,
    private readonly config: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const orgId = req.user?.orgId;
    if (!orgId) return true; // only per-org traffic is pooled

    const limit = Number(this.config.get('RATE_LIMIT_PER_MINUTE', 600));
    const windowSeconds = Number(this.config.get('RATE_LIMIT_WINDOW_SECONDS', 60));
    const bucket = Math.floor(Date.now() / 1000 / windowSeconds);
    const key = `ratelimit:org:${orgId}:${bucket}`;

    let count: number;
    try {
      count = await this.redis.incr(key);
      if (count === 1) {
        // First hit in this window — set the TTL so the counter self-clears.
        await this.redis.expire(key, windowSeconds);
      }
    } catch (error) {
      // Fail open — never let a limiter hiccup take the app down.
      this.logger.warn(
        `Rate-limit check skipped (Redis error): ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return true;
    }

    if (count > limit) {
      const res = context.switchToHttp().getResponse<Response>();
      res.setHeader('Retry-After', windowSeconds);
      throw new HttpException(
        "Your organization's rate limit has been exceeded. Please retry shortly.",
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    return true;
  }
}
