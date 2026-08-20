import { Injectable, NestMiddleware } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NextFunction, Request, Response } from 'express';

/**
 * Sets the standard security response headers (Phase 17.2).
 *
 * Deliberately dependency-free rather than pulling in helmet: this is a JSON
 * API (the Flutter frontend is served separately), so the handful of headers
 * that actually matter here are few and stable, and a hand-rolled middleware
 * avoids a new dependency — and the cross-platform lockfile regeneration that
 * every backend dependency change forces on CI. If a served-HTML surface with
 * a real Content-Security-Policy is ever added, helmet becomes worth it; until
 * then this covers the meaningful headers explicitly.
 *
 * HSTS is only emitted in production: sending Strict-Transport-Security over a
 * plaintext dev origin (http://localhost) would pin the browser to HTTPS for a
 * host that doesn't serve it, breaking local development.
 */
@Injectable()
export class SecurityHeadersMiddleware implements NestMiddleware {
  private readonly isProduction: boolean;

  constructor(config: ConfigService) {
    this.isProduction =
      config.get<string>('NODE_ENV', 'development') === 'production';
  }

  use(_req: Request, res: Response, next: NextFunction): void {
    // Don't advertise the framework.
    res.removeHeader('X-Powered-By');

    // Never let a browser MIME-sniff a response into something executable.
    res.setHeader('X-Content-Type-Options', 'nosniff');
    // This API is never meant to be framed — defence-in-depth against
    // clickjacking even though it returns JSON.
    res.setHeader('X-Frame-Options', 'DENY');
    // Don't leak full URLs (which may carry ids) to other origins.
    res.setHeader('Referrer-Policy', 'no-referrer');
    // Turn off legacy DNS prefetching of links in any returned content.
    res.setHeader('X-DNS-Prefetch-Control', 'off');
    // Isolate this origin's browsing context / resources.
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    // No caller needs these powerful browser features from an API response.
    res.setHeader(
      'Permissions-Policy',
      'camera=(), microphone=(), geolocation=(), browsing-topics=()',
    );

    if (this.isProduction) {
      // 180 days, include subdomains, and eligible for the preload list.
      res.setHeader(
        'Strict-Transport-Security',
        'max-age=15552000; includeSubDomains; preload',
      );
    }

    next();
  }
}
