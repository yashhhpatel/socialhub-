import { ConfigService } from '@nestjs/config';

import { FacebookAdapter } from './facebook.adapter';

function makeAdapter(
  overrides: Record<string, string> = {},
): FacebookAdapter {
  const configValues: Record<string, string> = {
    FACEBOOK_CLIENT_ID: 'test-client-id',
    FACEBOOK_CLIENT_SECRET: 'test-client-secret',
    FACEBOOK_REDIRECT_URI: 'http://localhost:3000/social-accounts/facebook/callback',
    ...overrides,
  };
  const configService = {
    // Non-throwing lookup — returns undefined for unset keys, which is how
    // the adapter probes the preferred FACEBOOK_APP_ID/SECRET names.
    get: jest.fn((key: string) => configValues[key]),
    getOrThrow: jest.fn((key: string) => {
      if (!(key in configValues)) throw new Error(`Missing config: ${key}`);
      return configValues[key];
    }),
  } as unknown as ConfigService;

  return new FacebookAdapter(configService);
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

describe('FacebookAdapter', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('capabilities', () => {
    it('returns image+video support with the documented rate limit', () => {
      const caps = makeAdapter().capabilities();

      expect(caps.supportedMediaTypes).toEqual(['image', 'video']);
      expect(caps.maxCaptionLength).toBe(63206);
      expect(caps.imageSpec.aspectRatio).toBe('1.91:1');
      expect(caps.rateLimit).toEqual({ requests: 200, windowSeconds: 3600 });
    });
  });

  describe('getAuthorizationUrl', () => {
    it('builds a URL with the correct host, client_id, redirect_uri, and state', () => {
      const url = new URL(makeAdapter().getAuthorizationUrl('test-state-value'));

      expect(url.origin + url.pathname).toBe(
        'https://www.facebook.com/v21.0/dialog/oauth',
      );
      expect(url.searchParams.get('client_id')).toBe('test-client-id');
      expect(url.searchParams.get('redirect_uri')).toBe(
        'http://localhost:3000/social-accounts/facebook/callback',
      );
      expect(url.searchParams.get('response_type')).toBe('code');
      expect(url.searchParams.get('state')).toBe('test-state-value');
    });

    it('prefers the FACEBOOK_APP_ID / FACEBOOK_APP_SECRET names when set (Meta terminology)', () => {
      const adapter = makeAdapter({
        FACEBOOK_APP_ID: 'app-id-123',
        FACEBOOK_APP_SECRET: 'app-secret-123',
      });
      const url = new URL(adapter.getAuthorizationUrl('s'));
      expect(url.searchParams.get('client_id')).toBe('app-id-123');
    });

    it('requests the page-management scopes needed to publish', () => {
      const url = new URL(makeAdapter().getAuthorizationUrl('s'));
      const scopes = url.searchParams.get('scope')?.split(',');

      expect(scopes).toContain('pages_show_list');
      expect(scopes).toContain('pages_manage_posts');
    });
  });

  describe('connect', () => {
    it('exchanges code -> long-lived user token -> page token, returning the PAGE id + token', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        // 1. code -> short-lived user token
        { ok: true, json: { access_token: 'user_short', token_type: 'bearer' } },
        // 2. short-lived -> long-lived user token
        { ok: true, json: { access_token: 'user_long', token_type: 'bearer', expires_in: 5184000 } },
        // 3. /me/accounts -> pages
        { ok: true, json: { data: [{ id: 'page_555', name: 'My Page', access_token: 'page_token_zzz' }] } },
        // 4. /me -> the authorizing user's id (for deauth/data-deletion matching)
        { ok: true, json: { id: 'user_999' } },
      ]);

      const result = await adapter.connect('auth-code');

      expect(fetchMock).toHaveBeenCalledTimes(4);
      // externalAccountId is the PAGE id, not the user id.
      expect(result.externalAccountId).toBe('page_555');
      // externalUserId is the USER id — what Meta's callbacks match on.
      expect(result.externalUserId).toBe('user_999');
      // accessToken is the PAGE token — what publish() posts with.
      expect(result.accessToken).toBe('page_token_zzz');
      expect(result.refreshToken).toBeUndefined();
      expect(result.expiresAt).toBeInstanceOf(Date);
      expect(result.expiresAt!.getTime()).toBeGreaterThan(
        Date.now() + 50 * 24 * 60 * 60 * 1000,
      );
    });

    it('throws with a clear message if the code exchange call fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'invalid_grant' }]);

      await expect(adapter.connect('bad-code')).rejects.toThrow(/code exchange failed/i);
    });

    it('throws a helpful message when the account administers no Page', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        { ok: true, json: { access_token: 'user_short' } },
        { ok: true, json: { access_token: 'user_long', expires_in: 5184000 } },
        { ok: true, json: { data: [] } },
        // /me runs in parallel with /me/accounts; provide its response too.
        { ok: true, json: { id: 'user_999' } },
      ]);

      await expect(adapter.connect('code')).rejects.toThrow(/no facebook page/i);
    });
  });

  describe('refresh', () => {
    it('re-runs the long-lived exchange in place and returns a new token + expiry', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        { ok: true, json: { access_token: 'user_long_refreshed', expires_in: 5184000 } },
      ]);

      const result = await adapter.refresh('current_long_lived_token');

      expect(result.accessToken).toBe('user_long_refreshed');
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('throws with a clear message if the refresh call fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'token_expired' }]);

      await expect(adapter.refresh('dead_token')).rejects.toThrow(/token exchange failed/i);
    });
  });

  describe('publish', () => {
    it('posts the photo to the Page and returns post_id as the external id', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        { ok: true, json: { id: '555_111', post_id: '555_999' } },
      ]);

      const result = await adapter.publish({
        imageUrl: 'https://cdn.example.com/variant.png',
        caption: 'hello world',
        externalAccountId: 'page_555',
        accessToken: 'page_token_zzz',
      });

      expect(fetchMock).toHaveBeenCalledTimes(1);
      const [calledUrl] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(calledUrl).toContain('/page_555/photos');
      // Prefers post_id (the feed story) over the raw photo id.
      expect(result.externalPostId).toBe('555_999');
    });

    it('falls back to id when the response has no post_id', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: true, json: { id: '555_111' } }]);

      const result = await adapter.publish({
        imageUrl: 'https://cdn.example.com/variant.png',
        caption: 'c',
        externalAccountId: 'page_555',
        accessToken: 'page_token_zzz',
      });

      expect(result.externalPostId).toBe('555_111');
    });

    it('throws with the platform error text preserved on failure', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: '(#200) Permissions error' }]);

      await expect(
        adapter.publish({
          imageUrl: 'https://cdn.example.com/variant.png',
          caption: 'c',
          externalAccountId: 'page_555',
          accessToken: 'page_token_zzz',
        }),
      ).rejects.toThrow(/Permissions error/);
    });
  });
});
