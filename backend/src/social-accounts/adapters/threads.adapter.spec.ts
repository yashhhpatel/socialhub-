import { ConfigService } from '@nestjs/config';

import { ThreadsAdapter } from './threads.adapter';

function makeAdapter(): ThreadsAdapter {
  const configValues: Record<string, string> = {
    THREADS_CLIENT_ID: 'test-client-id',
    THREADS_CLIENT_SECRET: 'test-client-secret',
    THREADS_REDIRECT_URI: 'http://localhost:3000/social-accounts/threads/callback',
  };
  const configService = {
    getOrThrow: jest.fn((key: string) => {
      if (!(key in configValues)) throw new Error(`Missing config: ${key}`);
      return configValues[key];
    }),
  } as unknown as ConfigService;

  return new ThreadsAdapter(configService);
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

describe('ThreadsAdapter', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('capabilities', () => {
    it('returns the documented caption limit and rate limit', () => {
      const caps = makeAdapter().capabilities();

      expect(caps.supportedMediaTypes).toEqual(['image', 'video']);
      expect(caps.maxCaptionLength).toBe(500);
      expect(caps.imageSpec.aspectRatio).toBe('1:1');
      expect(caps.rateLimit).toEqual({ requests: 250, windowSeconds: 86400 });
    });
  });

  describe('getAuthorizationUrl', () => {
    it('builds a URL with the correct host, client_id, redirect_uri, and state', () => {
      const url = new URL(makeAdapter().getAuthorizationUrl('test-state-value'));

      expect(url.origin + url.pathname).toBe('https://threads.net/oauth/authorize');
      expect(url.searchParams.get('client_id')).toBe('test-client-id');
      expect(url.searchParams.get('redirect_uri')).toBe(
        'http://localhost:3000/social-accounts/threads/callback',
      );
      expect(url.searchParams.get('response_type')).toBe('code');
      expect(url.searchParams.get('state')).toBe('test-state-value');
    });

    it('requests both the basic and content-publish scopes', () => {
      const url = new URL(makeAdapter().getAuthorizationUrl('s'));
      const scopes = url.searchParams.get('scope')?.split(',');

      expect(scopes).toContain('threads_basic');
      expect(scopes).toContain('threads_content_publish');
    });
  });

  describe('connect', () => {
    it('runs short-lived -> long-lived -> profile and returns the right shape', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        { ok: true, json: { access_token: 'short_abc', user_id: '123' } },
        { ok: true, json: { access_token: 'long_xyz', token_type: 'bearer', expires_in: 5184000 } },
        { ok: true, json: { id: 'th_user_789', username: 'testaccount' } },
      ]);

      const result = await adapter.connect('auth-code');

      expect(fetchMock).toHaveBeenCalledTimes(3);
      expect(result.externalAccountId).toBe('th_user_789');
      expect(result.accessToken).toBe('long_xyz');
      expect(result.refreshToken).toBeUndefined();
      expect(result.expiresAt).toBeInstanceOf(Date);
      expect(result.expiresAt!.getTime()).toBeGreaterThan(
        Date.now() + 50 * 24 * 60 * 60 * 1000,
      );
    });

    it('throws with a clear message if the code exchange fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'invalid_grant' }]);

      await expect(adapter.connect('bad-code')).rejects.toThrow(/code exchange failed/i);
    });

    it('throws if the code exchange returns no access token', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: true, json: { user_id: '1' } }]);

      await expect(adapter.connect('code')).rejects.toThrow(/no access token/i);
    });
  });

  describe('refresh', () => {
    it('calls the refresh endpoint and returns a new access token + expiry', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([
        { ok: true, json: { access_token: 'refreshed', token_type: 'bearer', expires_in: 5184000 } },
      ]);

      const result = await adapter.refresh('current_long_lived_token');

      expect(result.accessToken).toBe('refreshed');
      expect(result.expiresAt).toBeInstanceOf(Date);
    });

    it('throws with a clear message if the refresh call fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'token_expired' }]);

      await expect(adapter.refresh('dead_token')).rejects.toThrow(/refresh failed/i);
    });
  });

  describe('publish', () => {
    it('creates a container then publishes it, returning the post id', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        { ok: true, json: { id: 'container_1' } }, // create container
        { ok: true, json: { status: 'FINISHED' } }, // status poll
        { ok: true, json: { id: 'thread_post_9' } }, // publish
      ]);

      const result = await adapter.publish({
        imageUrl: 'https://cdn.example.com/variant.png',
        caption: 'hello threads',
        externalAccountId: 'th_user_789',
        accessToken: 'long_xyz',
      });

      expect(fetchMock).toHaveBeenCalledTimes(3);
      const [createUrl] = fetchMock.mock.calls[0] as [string, RequestInit];
      const [statusUrl] = fetchMock.mock.calls[1] as [string, RequestInit];
      const [publishUrl] = fetchMock.mock.calls[2] as [string, RequestInit];
      expect(createUrl).toContain('/th_user_789/threads');
      expect(statusUrl).toContain('/container_1?');
      expect(statusUrl).toContain('status');
      expect(publishUrl).toContain('/th_user_789/threads_publish');
      expect(result.externalPostId).toBe('thread_post_9');
    });

    it('throws with the platform error text preserved if container creation fails', async () => {
      const adapter = makeAdapter();
      mockFetchSequence([{ ok: false, text: 'Unsupported media' }]);

      await expect(
        adapter.publish({
          imageUrl: 'https://cdn.example.com/variant.png',
          caption: 'c',
          externalAccountId: 'th_user_789',
          accessToken: 'long_xyz',
        }),
      ).rejects.toThrow(/Unsupported media/);
    });
  });

  describe('publishCarousel', () => {
    it('waits for each child AND the parent to finish before publishing', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        { ok: true, json: { id: 'child_1' } }, // create item 1
        { ok: true, json: { status: 'FINISHED' } }, // item 1 ready
        { ok: true, json: { id: 'child_2' } }, // create item 2
        { ok: true, json: { status: 'FINISHED' } }, // item 2 ready
        { ok: true, json: { id: 'parent_1' } }, // create CAROUSEL parent
        { ok: true, json: { status: 'FINISHED' } }, // parent ready
        { ok: true, json: { id: 'thread_post_9' } }, // publish
      ]);

      const result = await adapter.publishCarousel({
        mediaUrls: ['https://cdn/a.png', 'https://cdn/b.png'],
        caption: 'my carousel',
        externalAccountId: 'th_user_789',
        accessToken: 'long_xyz',
      });

      expect(result.externalPostId).toBe('thread_post_9');
      expect(fetchMock).toHaveBeenCalledTimes(7);
      // The parent is created as a CAROUSEL listing both ready children.
      const [, parentInit] = fetchMock.mock.calls[4] as [string, RequestInit];
      const parentBody = parentInit.body as unknown as URLSearchParams;
      expect(parentBody.get('media_type')).toBe('CAROUSEL');
      expect(parentBody.get('children')).toBe('child_1,child_2');
    });

    it('aborts (does not publish) when a child container reports ERROR', async () => {
      const adapter = makeAdapter();
      const fetchMock = mockFetchSequence([
        { ok: true, json: { id: 'child_1' } }, // create item 1
        { ok: true, json: { status: 'ERROR' } }, // processing failed
      ]);

      await expect(
        adapter.publishCarousel({
          mediaUrls: ['https://cdn/a.png', 'https://cdn/b.png'],
          caption: 'c',
          externalAccountId: 'th_user_789',
          accessToken: 'long_xyz',
        }),
      ).rejects.toThrow(/could not process the media/i);
      expect(fetchMock).toHaveBeenCalledTimes(2);
    });
  });
});
