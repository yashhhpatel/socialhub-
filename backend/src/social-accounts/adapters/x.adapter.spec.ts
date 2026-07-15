import { ConfigService } from '@nestjs/config';

import { XAdapter } from './x.adapter';

function makeAdapter(): XAdapter {
  const configValues: Record<string, string> = {
    X_CLIENT_ID: 'test-x-client-id',
    X_CLIENT_SECRET: 'test-x-client-secret',
    X_REDIRECT_URI: 'http://localhost:3000/social-accounts/x/callback',
  };
  const configService = {
    getOrThrow: jest.fn((key: string) => {
      if (!(key in configValues)) throw new Error(`Missing config: ${key}`);
      return configValues[key];
    }),
  } as unknown as ConfigService;

  return new XAdapter(configService);
}

function mockFetchSequence(responses: Array<{ ok: boolean; json?: unknown; text?: string }>) {
  const mockFetch = jest.fn();
  for (const r of responses) {
    mockFetch.mockImplementationOnce(async () => ({
      ok: r.ok,
      status: r.ok ? 200 : 400,
      json: async () => r.json,
      text: async () => r.text ?? JSON.stringify(r.json ?? {}),
    }));
  }
  global.fetch = mockFetch as unknown as typeof fetch;
  return mockFetch;
}

describe('XAdapter', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('getAuthorizationUrl', () => {
    it('throws if called without a PKCE code challenge', () => {
      const adapter = makeAdapter();
      expect(() => adapter.getAuthorizationUrl('state')).toThrow(/codeChallenge/);
    });

    it('builds a URL with the correct host, PKCE params, and all 4 required scopes', () => {
      const adapter = makeAdapter();
      const url = new URL(adapter.getAuthorizationUrl('test-state', 'test-challenge'));

      expect(url.origin + url.pathname).toBe('https://x.com/i/oauth2/authorize');
      expect(url.searchParams.get('client_id')).toBe('test-x-client-id');
      expect(url.searchParams.get('state')).toBe('test-state');
      expect(url.searchParams.get('code_challenge')).toBe('test-challenge');
      expect(url.searchParams.get('code_challenge_method')).toBe('S256');

      const scopes = url.searchParams.get('scope')?.split(' ');
      expect(scopes).toEqual(
        expect.arrayContaining(['tweet.read', 'tweet.write', 'users.read', 'offline.access']),
      );
    });
  });

  describe('connect', () => {
    it('throws if called without a PKCE code verifier', async () => {
      const adapter = makeAdapter();
      await expect(adapter.connect('code')).rejects.toThrow(/codeVerifier/);
    });

    it('exchanges code+verifier for tokens, fetches profile, and uses Basic Auth', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        {
          ok: true,
          json: {
            token_type: 'bearer',
            expires_in: 7200,
            access_token: 'x_access_token',
            scope: 'tweet.read tweet.write users.read offline.access',
            refresh_token: 'x_refresh_token',
          },
        },
        { ok: true, json: { data: { id: 'x_user_123', username: 'testuser', name: 'Test User' } } },
      ]);

      const result = await adapter.connect('auth-code', 'code-verifier-value');

      expect(fetchMock).toHaveBeenCalledTimes(2);

      // First call: token exchange, must use Basic Auth + form-encoded body.
      const [tokenUrl, tokenOptions] = fetchMock.mock.calls[0];
      expect(tokenUrl).toBe('https://api.x.com/2/oauth2/token');
      expect(tokenOptions.headers.Authorization).toMatch(/^Basic /);
      const decoded = Buffer.from(
        tokenOptions.headers.Authorization.replace('Basic ', ''),
        'base64',
      ).toString();
      expect(decoded).toBe('test-x-client-id:test-x-client-secret');
      expect(tokenOptions.body.toString()).toContain('code_verifier=code-verifier-value');

      expect(result.externalAccountId).toBe('x_user_123');
      expect(result.accessToken).toBe('x_access_token');
      expect(result.refreshToken).toBe('x_refresh_token');
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('throws with a clear message if the token exchange fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'invalid_grant' }]);

      await expect(adapter.connect('bad-code', 'verifier')).rejects.toThrow(
        /code exchange failed/i,
      );
    });
  });

  describe('refresh', () => {
    it('rotates the refresh token — returns a NEW refresh_token, not the old one', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        {
          ok: true,
          json: {
            token_type: 'bearer',
            expires_in: 7200,
            access_token: 'new_access_token',
            scope: 'tweet.read tweet.write users.read offline.access',
            refresh_token: 'rotated_refresh_token',
          },
        },
      ]);

      const result = await adapter.refresh('old_refresh_token');

      expect(result.accessToken).toBe('new_access_token');
      expect(result.refreshToken).toBe('rotated_refresh_token');
      expect(result.refreshToken).not.toBe('old_refresh_token');
    });

    it('throws with a clear message if the refresh call fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'invalid_grant' }]);

      await expect(adapter.refresh('dead_token')).rejects.toThrow(/refresh failed/i);
    });
  });
});
