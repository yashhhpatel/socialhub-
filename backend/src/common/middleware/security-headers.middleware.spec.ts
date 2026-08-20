import { ConfigService } from '@nestjs/config';
import { NextFunction, Request, Response } from 'express';

import { SecurityHeadersMiddleware } from './security-headers.middleware';

function makeResponse() {
  const headers = new Map<string, string>();
  const res = {
    setHeader: jest.fn((k: string, v: string) => headers.set(k, v)),
    removeHeader: jest.fn((k: string) => headers.delete(k)),
  } as unknown as Response;
  return { res, headers };
}

function makeMiddleware(nodeEnv: string) {
  const config = {
    get: jest.fn((_key: string, fallback?: string) => nodeEnv ?? fallback),
  } as unknown as ConfigService;
  return new SecurityHeadersMiddleware(config);
}

describe('SecurityHeadersMiddleware', () => {
  it('sets the core hardening headers and strips X-Powered-By', () => {
    const mw = makeMiddleware('development');
    const { res, headers } = makeResponse();
    const next = jest.fn() as NextFunction;

    mw.use({} as Request, res, next);

    expect(res.removeHeader).toHaveBeenCalledWith('X-Powered-By');
    expect(headers.get('X-Content-Type-Options')).toBe('nosniff');
    expect(headers.get('X-Frame-Options')).toBe('DENY');
    expect(headers.get('Referrer-Policy')).toBe('no-referrer');
    expect(headers.get('Cross-Origin-Opener-Policy')).toBe('same-origin');
    expect(headers.get('Cross-Origin-Resource-Policy')).toBe('same-origin');
    expect(headers.get('Permissions-Policy')).toContain('geolocation=()');
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('omits HSTS in development (would break plaintext localhost)', () => {
    const mw = makeMiddleware('development');
    const { res, headers } = makeResponse();
    mw.use({} as Request, res, jest.fn() as NextFunction);
    expect(headers.has('Strict-Transport-Security')).toBe(false);
  });

  it('emits HSTS in production', () => {
    const mw = makeMiddleware('production');
    const { res, headers } = makeResponse();
    mw.use({} as Request, res, jest.fn() as NextFunction);
    expect(headers.get('Strict-Transport-Security')).toContain('max-age=');
    expect(headers.get('Strict-Transport-Security')).toContain('includeSubDomains');
  });
});
