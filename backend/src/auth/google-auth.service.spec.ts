import {
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';

import { GoogleAuthService } from './google-auth.service';

/** Builds a fake Google id_token (header.payload.sig) with the given claims. */
function makeIdToken(claims: Record<string, unknown>): string {
  const b64 = (o: unknown) =>
    Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'RS256' })}.${b64(claims)}.sig`;
}

const CLIENT_ID = 'client-123.apps.googleusercontent.com';

function validClaims(over: Record<string, unknown> = {}) {
  return {
    iss: 'https://accounts.google.com',
    aud: CLIENT_ID,
    sub: 'google-sub-1',
    email: 'New.User@Example.com',
    email_verified: true,
    exp: Math.floor(Date.now() / 1000) + 3600,
    ...over,
  };
}

describe('GoogleAuthService', () => {
  let service: GoogleAuthService;
  let config: { get: jest.Mock };
  let jwt: { signAsync: jest.Mock; verifyAsync: jest.Mock };
  let prisma: {
    user: { findUnique: jest.Mock; update: jest.Mock };
    userToken: { create: jest.Mock; findUnique: jest.Mock; update: jest.Mock };
    $transaction: jest.Mock;
  };
  let auth: { issueSession: jest.Mock };

  const configMap: Record<string, string> = {
    GOOGLE_CLIENT_ID: CLIENT_ID,
    GOOGLE_CLIENT_SECRET: 'secret',
    GOOGLE_REDIRECT_URI: 'http://localhost:3000/auth/google/callback',
    FRONTEND_URL: 'http://localhost:8080',
  };

  beforeEach(() => {
    config = {
      get: jest.fn((key: string, fallback?: string) => configMap[key] ?? fallback),
    };
    jwt = {
      signAsync: jest.fn().mockResolvedValue('signed-state'),
      verifyAsync: jest.fn().mockResolvedValue({ purpose: 'google_oauth_state' }),
    };
    prisma = {
      user: { findUnique: jest.fn(), update: jest.fn() },
      userToken: { create: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
      $transaction: jest.fn(),
    };
    auth = { issueSession: jest.fn() };
    service = new GoogleAuthService(
      config as never,
      jwt as never,
      prisma as never,
      auth as never,
    );
  });

  afterEach(() => jest.restoreAllMocks());

  describe('configuration gate', () => {
    it('is enabled when id + secret are present', () => {
      expect(service.enabled).toBe(true);
    });

    it('503s buildConsentUrl when not configured', async () => {
      config.get.mockReturnValue(undefined);
      await expect(service.buildConsentUrl()).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
    });

    it('builds a consent URL with the right client id, redirect and state', async () => {
      const url = await service.buildConsentUrl();
      expect(url).toContain('accounts.google.com/o/oauth2/v2/auth');
      expect(url).toContain(`client_id=${encodeURIComponent(CLIENT_ID)}`);
      expect(url).toContain('state=signed-state');
      expect(url).toContain('scope=openid+email+profile');
    });
  });

  describe('handleCallback', () => {
    function stubTokenExchange(claims: Record<string, unknown>) {
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ id_token: makeIdToken(claims) }),
      }) as unknown as typeof fetch;
    }

    it('creates a new user + workspace and returns a ticket URL', async () => {
      stubTokenExchange(validClaims());
      prisma.user.findUnique.mockResolvedValue(null); // no googleId, no email
      prisma.$transaction.mockResolvedValue({ id: 'usr_new' });
      prisma.userToken.create.mockResolvedValue({});

      const url = await service.handleCallback('code', 'state');

      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
      expect(prisma.userToken.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          userId: 'usr_new',
          type: 'google_login_handoff',
        }),
      });
      expect(url).toMatch(/^http:\/\/localhost:8080\/#\/auth\/google\?ticket=/);
    });

    it('links Google to an existing email account instead of duplicating', async () => {
      stubTokenExchange(validClaims());
      // 1st lookup by googleId -> null; 2nd by email -> existing user
      prisma.user.findUnique
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: 'usr_existing',
          googleId: null,
          emailVerifiedAt: null,
        });
      prisma.user.update.mockResolvedValue({});
      prisma.userToken.create.mockResolvedValue({});

      await service.handleCallback('code', 'state');

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'usr_existing' },
        data: expect.objectContaining({ googleId: 'google-sub-1' }),
      });
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('returns the existing user directly when already linked', async () => {
      stubTokenExchange(validClaims());
      prisma.user.findUnique.mockResolvedValueOnce({ id: 'usr_linked' });
      prisma.userToken.create.mockResolvedValue({});

      await service.handleCallback('code', 'state');

      expect(prisma.user.update).not.toHaveBeenCalled();
      expect(prisma.$transaction).not.toHaveBeenCalled();
      expect(prisma.userToken.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ userId: 'usr_linked' }),
      });
    });

    it('rejects a token whose audience is not our client id', async () => {
      stubTokenExchange(validClaims({ aud: 'someone-else' }));
      await expect(service.handleCallback('code', 'state')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects an unverified email', async () => {
      stubTokenExchange(validClaims({ email_verified: false }));
      await expect(service.handleCallback('code', 'state')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects an expired id_token', async () => {
      stubTokenExchange(validClaims({ exp: Math.floor(Date.now() / 1000) - 10 }));
      await expect(service.handleCallback('code', 'state')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects a bad state', async () => {
      jwt.verifyAsync.mockRejectedValue(new Error('bad'));
      await expect(service.handleCallback('code', 'state')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('exchangeTicket', () => {
    it('burns a valid ticket and issues a session', async () => {
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok1',
        type: 'google_login_handoff',
        consumedAt: null,
        expiresAt: new Date(Date.now() + 60_000),
        user: { id: 'u1', email: 'a@b.com', role: 'owner', orgId: 'org1' },
      });
      prisma.userToken.update.mockResolvedValue({});
      auth.issueSession.mockResolvedValue({ accessToken: 'x' });

      const res = await service.exchangeTicket('raw');

      expect(prisma.userToken.update).toHaveBeenCalledWith({
        where: { id: 'tok1' },
        data: { consumedAt: expect.any(Date) },
      });
      expect(auth.issueSession).toHaveBeenCalledWith('u1', 'a@b.com', 'owner', 'org1');
      expect(res).toEqual({ accessToken: 'x' });
    });

    it('rejects an unknown ticket', async () => {
      prisma.userToken.findUnique.mockResolvedValue(null);
      await expect(service.exchangeTicket('raw')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects an already-consumed ticket', async () => {
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok1',
        type: 'google_login_handoff',
        consumedAt: new Date(),
        expiresAt: new Date(Date.now() + 60_000),
        user: { id: 'u1' },
      });
      await expect(service.exchangeTicket('raw')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      expect(auth.issueSession).not.toHaveBeenCalled();
    });

    it('rejects an expired ticket', async () => {
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok1',
        type: 'google_login_handoff',
        consumedAt: null,
        expiresAt: new Date(Date.now() - 10),
        user: { id: 'u1' },
      });
      await expect(service.exchangeTicket('raw')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects a ticket of the wrong type', async () => {
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok1',
        type: 'password_reset',
        consumedAt: null,
        expiresAt: new Date(Date.now() + 60_000),
        user: { id: 'u1' },
      });
      await expect(service.exchangeTicket('raw')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });
});
