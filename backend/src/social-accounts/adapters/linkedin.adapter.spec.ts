import { ConfigService } from '@nestjs/config';

import { LinkedInAdapter } from './linkedin.adapter';

function makeAdapter(): LinkedInAdapter {
  const configValues: Record<string, string> = {
    LINKEDIN_CLIENT_ID: 'test-client-id',
    LINKEDIN_CLIENT_SECRET: 'test-client-secret',
    LINKEDIN_REDIRECT_URI: 'http://localhost:3000/social-accounts/linkedin/callback',
  };
  const configService = {
    getOrThrow: jest.fn((key: string) => {
      if (!(key in configValues)) throw new Error(`Missing config: ${key}`);
      return configValues[key];
    }),
  } as unknown as ConfigService;

  return new LinkedInAdapter(configService);
}

interface MockResponse {
  ok: boolean;
  json?: unknown;
  text?: string;
  headers?: Record<string, string>;
}

function mockFetchSequence(responses: MockResponse[]) {
  const mockFetch = jest.fn();
  for (const r of responses) {
    mockFetch.mockImplementationOnce(async () => ({
      ok: r.ok,
      status: r.ok ? 200 : 400,
      json: async () => r.json,
      text: async () => r.text ?? JSON.stringify(r.json ?? {}),
      arrayBuffer: async () => new ArrayBuffer(8),
      headers: {
        get: (name: string) => r.headers?.[name.toLowerCase()] ?? null,
      },
    }));
  }
  global.fetch = mockFetch as unknown as typeof fetch;
  return mockFetch;
}

describe('LinkedInAdapter', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('capabilities', () => {
    it('returns the documented caption limit and image ratio', () => {
      const caps = makeAdapter().capabilities();

      expect(caps.maxCaptionLength).toBe(3000);
      expect(caps.imageSpec.aspectRatio).toBe('1.91:1');
      expect(caps.rateLimit).toEqual({ requests: 100, windowSeconds: 86400 });
    });
  });

  describe('getAuthorizationUrl', () => {
    it('builds a URL with the correct host, client_id, redirect_uri, and state', () => {
      const url = new URL(makeAdapter().getAuthorizationUrl('test-state-value'));

      expect(url.origin + url.pathname).toBe(
        'https://www.linkedin.com/oauth/v2/authorization',
      );
      expect(url.searchParams.get('client_id')).toBe('test-client-id');
      expect(url.searchParams.get('redirect_uri')).toBe(
        'http://localhost:3000/social-accounts/linkedin/callback',
      );
      expect(url.searchParams.get('response_type')).toBe('code');
      expect(url.searchParams.get('state')).toBe('test-state-value');
    });

    it('requests the openid + w_member_social scopes (space-delimited)', () => {
      const url = new URL(makeAdapter().getAuthorizationUrl('s'));
      const scopes = url.searchParams.get('scope')?.split(' ');

      expect(scopes).toContain('openid');
      expect(scopes).toContain('w_member_social');
    });
  });

  describe('connect', () => {
    it('exchanges the code then reads userinfo, storing sub as the account id', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        { ok: true, json: { access_token: 'li_access', expires_in: 5184000, refresh_token: 'li_refresh', scope: 'openid', token_type: 'Bearer' } },
        { ok: true, json: { sub: 'member_abc', name: 'Test Member' } },
      ]);

      const result = await adapter.connect('auth-code');

      expect(fetchMock).toHaveBeenCalledTimes(2);
      expect(result.externalAccountId).toBe('member_abc');
      expect(result.accessToken).toBe('li_access');
      expect(result.refreshToken).toBe('li_refresh');
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('passes through the absence of a refresh token (unapproved apps get none)', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        { ok: true, json: { access_token: 'li_access', expires_in: 5184000, scope: 'openid', token_type: 'Bearer' } },
        { ok: true, json: { sub: 'member_abc' } },
      ]);

      const result = await adapter.connect('code');

      expect(result.refreshToken).toBeUndefined();
    });

    it('throws with a clear message if the code exchange fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'invalid_grant' }]);

      await expect(adapter.connect('bad-code')).rejects.toThrow(/code exchange failed/i);
    });

    it('throws if userinfo has no member id', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        { ok: true, json: { access_token: 'li_access', expires_in: 5184000, scope: 'openid', token_type: 'Bearer' } },
        { ok: true, json: {} },
      ]);

      await expect(adapter.connect('code')).rejects.toThrow(/no member id/i);
    });
  });

  describe('refresh', () => {
    it('rotates and returns a new token pair', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        { ok: true, json: { access_token: 'li_new', refresh_token: 'li_new_refresh', expires_in: 5184000, scope: 'openid', token_type: 'Bearer' } },
      ]);

      const result = await adapter.refresh('current_refresh');

      expect(result.accessToken).toBe('li_new');
      expect(result.refreshToken).toBe('li_new_refresh');
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('throws with a clear message if the refresh call fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'token_expired' }]);

      await expect(adapter.refresh('dead')).rejects.toThrow(/refresh failed/i);
    });
  });

  describe('publish', () => {
    it('inits the upload, PUTs the bytes, creates the post, and reads the id from the header', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        // 1. initialize upload
        { ok: true, json: { value: { uploadUrl: 'https://upload.linkedin.com/abc', image: 'urn:li:image:xyz' } } },
        // 2. download the rendered image bytes from Cloudinary
        { ok: true, json: {} },
        // 3. PUT bytes to the upload URL
        { ok: true, json: {} },
        // 4. create post -> id in x-restli-id header
        { ok: true, json: {}, headers: { 'x-restli-id': 'urn:li:share:9988' } },
      ]);

      const result = await adapter.publish({
        imageUrl: 'https://cdn.example.com/variant.png',
        caption: 'hello linkedin',
        externalAccountId: 'member_abc',
        accessToken: 'li_access',
      });

      // 3 LinkedIn calls + 1 to fetch the image bytes = 4 fetches total.
      expect(fetchMock).toHaveBeenCalledTimes(4);
      const [initUrl] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(initUrl).toContain('/images?action=initializeUpload');
      expect(result.externalPostId).toBe('urn:li:share:9988');
    });

    it('throws when the create-post response carries no id header', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        { ok: true, json: { value: { uploadUrl: 'https://upload.linkedin.com/abc', image: 'urn:li:image:xyz' } } },
        { ok: true, json: {} }, // image download
        { ok: true, json: {} }, // PUT upload
        { ok: true, json: {}, headers: {} }, // create post, no id header
      ]);

      await expect(
        adapter.publish({
          imageUrl: 'https://cdn.example.com/variant.png',
          caption: 'c',
          externalAccountId: 'member_abc',
          accessToken: 'li_access',
        }),
      ).rejects.toThrow(/no post id/i);
    });

    it('throws with the platform error text preserved if upload init fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'ACCESS_DENIED' }]);

      await expect(
        adapter.publish({
          imageUrl: 'https://cdn.example.com/variant.png',
          caption: 'c',
          externalAccountId: 'member_abc',
          accessToken: 'li_access',
        }),
      ).rejects.toThrow(/ACCESS_DENIED/);
    });
  });
});
