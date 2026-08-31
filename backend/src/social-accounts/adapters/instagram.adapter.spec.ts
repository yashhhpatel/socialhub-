import { ConfigService } from '@nestjs/config';

import { InstagramAdapter } from './instagram.adapter';

function makeAdapter(): InstagramAdapter {
  const configValues: Record<string, string> = {
    INSTAGRAM_CLIENT_ID: 'test-client-id',
    INSTAGRAM_CLIENT_SECRET: 'test-client-secret',
    INSTAGRAM_REDIRECT_URI: 'http://localhost:3000/social-accounts/instagram/callback',
  };
  const configService = {
    getOrThrow: jest.fn((key: string) => {
      if (!(key in configValues)) throw new Error(`Missing config: ${key}`);
      return configValues[key];
    }),
  } as unknown as ConfigService;

  return new InstagramAdapter(configService);
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

describe('InstagramAdapter', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('capabilities', () => {
    it('returns image+video support with the documented rate limit', () => {
      const adapter = makeAdapter();
      const caps = adapter.capabilities();

      expect(caps.supportedMediaTypes).toEqual(['image', 'video']);
      expect(caps.rateLimit).toEqual({ requests: 200, windowSeconds: 3600 });
    });
  });

  describe('getAuthorizationUrl', () => {
    it('builds a URL with the correct host, client_id, redirect_uri, and state', () => {
      const adapter = makeAdapter();
      const url = new URL(adapter.getAuthorizationUrl('test-state-value'));

      expect(url.origin + url.pathname).toBe('https://www.instagram.com/oauth/authorize');
      expect(url.searchParams.get('client_id')).toBe('test-client-id');
      expect(url.searchParams.get('redirect_uri')).toBe(
        'http://localhost:3000/social-accounts/instagram/callback',
      );
      expect(url.searchParams.get('response_type')).toBe('code');
      expect(url.searchParams.get('state')).toBe('test-state-value');
    });

    it('requests both the basic and content-publish scopes', () => {
      const adapter = makeAdapter();
      const url = new URL(adapter.getAuthorizationUrl('s'));
      const scopes = url.searchParams.get('scope')?.split(',');

      expect(scopes).toContain('instagram_business_basic');
      expect(scopes).toContain('instagram_business_content_publish');
    });
  });

  describe('connect', () => {
    it('runs the full 3-call sequence (short-lived -> long-lived -> profile) and returns the right shape', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        // 1. code -> short-lived token
        { ok: true, json: { data: [{ access_token: 'short_lived_abc', user_id: '123', permissions: 'x' }] } },
        // 2. short-lived -> long-lived token
        { ok: true, json: { access_token: 'long_lived_xyz', token_type: 'bearer', expires_in: 5184000 } },
        // 3. profile fetch
        { ok: true, json: { id: 'ig_user_789', username: 'testaccount' } },
      ]);

      const result = await adapter.connect('auth-code-from-callback');

      expect(fetchMock).toHaveBeenCalledTimes(3);
      expect(result.externalAccountId).toBe('ig_user_789');
      expect(result.accessToken).toBe('long_lived_xyz');
      expect(result.refreshToken).toBeUndefined(); // Instagram has no separate refresh token
      expect(result.expiresAt).toBeInstanceOf(Date);
      // expires_in was ~60 days in seconds; roughly confirm it's in the future by that much
      expect(result.expiresAt!.getTime()).toBeGreaterThan(Date.now() + 50 * 24 * 60 * 60 * 1000);
    });

    it('also accepts the flat token-response shape ({ access_token } without a data wrapper)', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        // 1. code -> short-lived token, FLAT shape (Meta ships this variant too)
        { ok: true, json: { access_token: 'short_lived_flat', user_id: '123' } },
        // 2. short-lived -> long-lived token
        { ok: true, json: { access_token: 'long_lived_xyz', token_type: 'bearer', expires_in: 5184000 } },
        // 3. profile fetch
        { ok: true, json: { id: 'ig_user_789', username: 'testaccount' } },
      ]);

      const result = await adapter.connect('auth-code-from-callback');

      expect(fetchMock).toHaveBeenCalledTimes(3);
      expect(result.externalAccountId).toBe('ig_user_789');
      expect(result.accessToken).toBe('long_lived_xyz');
    });

    it('throws with a clear message if the code exchange call fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'invalid_grant' }]);

      await expect(adapter.connect('bad-code')).rejects.toThrow(/code exchange failed/i);
    });

    it('throws if the token exchange response is missing an access token', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: true, json: { data: [] } }]);

      await expect(adapter.connect('code')).rejects.toThrow(/no access token/i);
    });
  });

  describe('refresh', () => {
    it('calls the refresh endpoint and returns a new access token + expiry', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        { ok: true, json: { access_token: 'refreshed_token', token_type: 'bearer', expires_in: 5184000 } },
      ]);

      const result = await adapter.refresh('current_long_lived_token');

      expect(result.accessToken).toBe('refreshed_token');
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('throws with a clear message if the refresh call fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'token_expired' }]);

      await expect(adapter.refresh('dead_token')).rejects.toThrow(/refresh failed/i);
    });
  });
});

describe('InstagramAdapter publishCarousel', () => {
  afterEach(() => jest.restoreAllMocks());

  const request = {
    mediaUrls: ['https://cdn.test/a.png', 'https://cdn.test/b.png'],
    caption: 'my carousel',
    externalAccountId: 'ig_123',
    accessToken: 'tok',
  };

  it('creates a child container per image, a CAROUSEL parent, then publishes', async () => {
    const fetchMock = mockFetchSequence([
      { ok: true, json: { id: 'child_1' } }, // item 1
      { ok: true, json: { status_code: 'FINISHED' } }, // item 1 ready
      { ok: true, json: { id: 'child_2' } }, // item 2
      { ok: true, json: { status_code: 'FINISHED' } }, // item 2 ready
      { ok: true, json: { id: 'parent_1' } }, // carousel container
      { ok: true, json: { status_code: 'FINISHED' } }, // parent ready
      { ok: true, json: { id: 'post_1' } }, // media_publish
    ]);

    const result = await makeAdapter().publishCarousel(request);

    expect(result.externalPostId).toBe('post_1');
    expect(fetchMock).toHaveBeenCalledTimes(7);

    // The parent container is created as a CAROUSEL listing both children.
    const parentBody = (fetchMock.mock.calls[4][1] as { body: URLSearchParams })
      .body as unknown as URLSearchParams;
    expect(parentBody.get('media_type')).toBe('CAROUSEL');
    expect(parentBody.get('children')).toBe('child_1,child_2');
    expect(parentBody.get('caption')).toBe('my carousel');
  });

  it('throws with the platform error text when a child container fails', async () => {
    mockFetchSequence([{ ok: false, text: 'bad image url' }]);
    await expect(makeAdapter().publishCarousel(request)).rejects.toThrow(
      /carousel item creation failed/i,
    );
  });
});

describe('InstagramAdapter publish', () => {
  afterEach(() => jest.restoreAllMocks());

  const request = {
    imageUrl: 'https://cdn.test/a.png',
    caption: 'hello',
    externalAccountId: 'ig_123',
    accessToken: 'tok',
  };

  it('creates the container, waits for it to finish, then publishes', async () => {
    const fetchMock = mockFetchSequence([
      { ok: true, json: { id: 'container_1' } }, // create container
      { ok: true, json: { status_code: 'FINISHED' } }, // status poll
      { ok: true, json: { id: 'post_1' } }, // media_publish
    ]);

    const result = await makeAdapter().publish(request);

    expect(result.externalPostId).toBe('post_1');
    expect(fetchMock).toHaveBeenCalledTimes(3);
    // The middle call is the status check on the container.
    expect((fetchMock.mock.calls[1][0] as string)).toContain('status_code');
    expect((fetchMock.mock.calls[1][0] as string)).toContain('container_1');
  });

  it('throws (and does not publish) when the container reports ERROR', async () => {
    const fetchMock = mockFetchSequence([
      { ok: true, json: { id: 'container_1' } }, // create container
      { ok: true, json: { status_code: 'ERROR' } }, // processing failed
    ]);

    await expect(makeAdapter().publish(request)).rejects.toThrow(
      /could not process the media/i,
    );
    // Never reached media_publish.
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });
});
