import {
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Redis } from 'ioredis';

import { RATE_LIMIT_REDIS } from '../common/rate-limit/rate-limit.tokens';

/**
 * Brute-force protection for the public auth surface (Phase 17.2).
 *
 * Two complementary concerns, both backed by the shared rate-limit Redis:
 *
 *  1. FAILURE-BASED login lockout. Counters keyed on the target email AND on
 *     the caller's IP are incremented only on a *failed* login and cleared on
 *     success — so a legitimate user who mistypes once isn't punished, but a
 *     credential-stuffing run (many emails from one IP) or a targeted guess
 *     (many passwords for one email) trips the lock. Either counter crossing
 *     its threshold blocks further attempts until the window rolls over.
 *
 *  2. Per-IP FLOOD limiting for unauthenticated POSTs that send email
 *     (password-reset request), so the endpoint can't be used to mail-bomb an
 *     address or enumerate at speed. This counts every call, not just
 *     failures.
 *
 * FAILS OPEN: every Redis interaction is guarded so a limiter outage degrades
 * to "no throttling", never to "auth is down" — matching OrgRateLimitGuard.
 */
@Injectable()
export class AuthThrottleService {
  private readonly logger = new Logger(AuthThrottleService.name);

  constructor(
    @Inject(RATE_LIMIT_REDIS) private readonly redis: Redis,
    private readonly config: ConfigService,
  ) {}

  private get windowSeconds(): number {
    return Number(this.config.get('AUTH_THROTTLE_WINDOW_SECONDS', 900)); // 15m
  }

  private get maxPerEmail(): number {
    return Number(this.config.get('AUTH_THROTTLE_MAX_PER_EMAIL', 5));
  }

  private get maxPerIp(): number {
    return Number(this.config.get('AUTH_THROTTLE_MAX_PER_IP', 20));
  }

  private get maxFloodPerIp(): number {
    return Number(this.config.get('AUTH_FLOOD_MAX_PER_IP', 10));
  }

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }

  private tooMany(): HttpException {
    // Generic message + 429; deliberately doesn't say whether it was the email
    // or the IP that tripped, nor how many attempts remain.
    const err = new HttpException(
      'Too many attempts. Please wait a few minutes and try again.',
      HttpStatus.TOO_MANY_REQUESTS,
    );
    return err;
  }

  /**
   * Call BEFORE checking credentials. Throws 429 if either the email or the IP
   * is already locked out for the current window.
   */
  async assertLoginAllowed(email: string, ip: string): Promise<void> {
    const emailCount = await this.peek(this.emailKey(this.normalizeEmail(email)));
    if (emailCount >= this.maxPerEmail) throw this.tooMany();

    const ipCount = await this.peek(this.ipKey(ip));
    if (ipCount >= this.maxPerIp) throw this.tooMany();
  }

  /** Call after a failed login — increments both the email and IP counters. */
  async recordLoginFailure(email: string, ip: string): Promise<void> {
    await this.bump(this.emailKey(this.normalizeEmail(email)));
    await this.bump(this.ipKey(ip));
  }

  /** Call after a successful login — clears the email counter for a clean slate. */
  async recordLoginSuccess(email: string): Promise<void> {
    try {
      await this.redis.del(this.emailKey(this.normalizeEmail(email)));
    } catch (error) {
      this.logInfoOnly(error);
    }
  }

  /**
   * Per-IP flood check for email-sending public endpoints. Counts this call and
   * throws 429 once the IP exceeds the flood allowance for the window.
   */
  async assertNotFlooding(ip: string, scope: string): Promise<void> {
    const key = `authflood:${scope}:${ip}`;
    const count = await this.bump(key);
    if (count > this.maxFloodPerIp) throw this.tooMany();
  }

  private emailKey(email: string): string {
    const bucket = this.bucket();
    return `authfail:email:${email}:${bucket}`;
  }

  private ipKey(ip: string): string {
    const bucket = this.bucket();
    return `authfail:ip:${ip}:${bucket}`;
  }

  private bucket(): number {
    return Math.floor(Date.now() / 1000 / this.windowSeconds);
  }

  /** Read a counter without mutating it. Returns 0 on any Redis error. */
  private async peek(key: string): Promise<number> {
    try {
      const raw = await this.redis.get(key);
      return raw ? Number(raw) : 0;
    } catch (error) {
      this.logInfoOnly(error);
      return 0;
    }
  }

  /**
   * Increment a fixed-window counter, setting the TTL on first hit. Returns the
   * new count, or 0 on a Redis error (fail open — the caller's threshold checks
   * then simply never trip).
   */
  private async bump(key: string): Promise<number> {
    try {
      const count = await this.redis.incr(key);
      if (count === 1) await this.redis.expire(key, this.windowSeconds);
      return count;
    } catch (error) {
      this.logInfoOnly(error);
      return 0;
    }
  }

  private logInfoOnly(error: unknown): void {
    this.logger.warn(
      `Auth throttle check skipped (Redis error): ${
        error instanceof Error ? error.message : String(error)
      }`,
    );
  }
}
