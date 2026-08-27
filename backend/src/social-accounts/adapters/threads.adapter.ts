import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  OAuthConnectionResult,
  CarouselPublishRequest,
  PublishRequest,
  PublishResult,
  PlatformAdapter,
  PlatformCapabilities,
  PlatformName,
  RefreshedTokens,
} from './adapter.interface';

const AUTHORIZE_URL = 'https://threads.net/oauth/authorize';
const GRAPH_BASE = 'https://graph.threads.net';
const API_BASE = `${GRAPH_BASE}/v1.0`;
const TOKEN_URL = `${GRAPH_BASE}/oauth/access_token`;
const LONG_LIVED_TOKEN_URL = `${GRAPH_BASE}/access_token`;
const REFRESH_URL = `${GRAPH_BASE}/refresh_access_token`;

// threads_basic: read profile. threads_content_publish: required for the
// publish flow — requested up front so the one-time consent screen already
// covers it (re-requesting scopes later would force a reconnect).
const SCOPES = ['threads_basic', 'threads_content_publish'];

interface ThreadsShortLivedTokenResponse {
  access_token: string;
  user_id: string;
}

interface ThreadsLongLivedTokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number; // seconds (~60 days)
}

interface ThreadsProfileResponse {
  id: string;
  username: string;
}

/**
 * Publishes to Threads via Meta's Threads API — verified against the
 * current (2026) docs before writing this. Threads is a Meta product and
 * its API deliberately mirrors Instagram's: OAuth with a short-lived ->
 * long-lived token exchange, and a two-step "create container, then
 * publish container" post flow. So this adapter is structurally close to
 * the Instagram one, and the shared shape is real rather than forced.
 *
 * TOKEN MODEL: like Instagram, Threads has no separate OAuth refresh
 * token — the SAME long-lived access token is refreshed in place
 * (th_refresh_token). refresh()'s `refreshToken` parameter therefore
 * receives the current long-lived ACCESS token, not a distinct refresh
 * token. Documented here and mirrored at the SocialAccountsService call
 * site (which passes the stored access token in).
 *
 * MEDIA PROCESSING QUIRK: Threads recommends a short wait between creating
 * an image container and publishing it, to let media processing finish.
 * This adapter does NOT sleep between the two steps — matching the
 * Instagram adapter, and because a fixed in-worker sleep would add latency
 * to every publish while still not guaranteeing readiness. If a container
 * genuinely isn't ready, the publish step fails with the platform's own
 * error and the queue's retry (with backoff) is the right place for the
 * wait, not a hardcoded delay here.
 *
 * Uses Node's built-in global fetch, like the other adapters.
 */
@Injectable()
export class ThreadsAdapter implements PlatformAdapter {
  readonly platform: PlatformName = 'threads';

  constructor(private readonly configService: ConfigService) {}

  capabilities(): PlatformCapabilities {
    return {
      supportedMediaTypes: ['image', 'video'],
      maxCaptionLength: 500, // Threads' documented post text limit
      maxCarouselItems: 20, // Threads carousels take 2–20 items.
      maxVideoDurationSeconds: 300, // 5 minutes
      imageSpec: {
        // 1:1 — the safe default that displays without Threads re-cropping,
        // same reasoning as Instagram's square feed image.
        width: 1080,
        height: 1080,
        aspectRatio: '1:1',
      },
      rateLimit: {
        // Threads' published publishing limit: 250 posts per 24h per user.
        requests: 250,
        windowSeconds: 86400,
      },
    };
  }

  getAuthorizationUrl(state: string): string {
    const params = new URLSearchParams({
      client_id: this.configService.getOrThrow<string>('THREADS_CLIENT_ID'),
      redirect_uri: this.configService.getOrThrow<string>('THREADS_REDIRECT_URI'),
      response_type: 'code',
      scope: SCOPES.join(','),
      state,
    });

    return `${AUTHORIZE_URL}?${params.toString()}`;
  }

  async connect(authorizationCode: string): Promise<OAuthConnectionResult> {
    const shortLived = await this.exchangeCodeForShortLivedToken(authorizationCode);
    const longLived = await this.exchangeForLongLivedToken(shortLived.access_token);
    const profile = await this.fetchProfile(longLived.access_token);

    return {
      externalAccountId: profile.id,
      // For Threads the account id IS the user id Meta's deauthorize/
      // data-deletion callbacks reference.
      externalUserId: profile.id,
      accessToken: longLived.access_token,
      // No separate refresh token for Threads — see class doc comment.
      expiresAt: new Date(Date.now() + longLived.expires_in * 1000),
    };
  }

  async refresh(refreshToken: string): Promise<RefreshedTokens> {
    // `refreshToken` here is the current long-lived access token — see
    // class doc comment on why.
    const params = new URLSearchParams({
      grant_type: 'th_refresh_token',
      access_token: refreshToken,
    });

    const response = await fetch(`${REFRESH_URL}?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Threads token refresh failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as ThreadsLongLivedTokenResponse;

    return {
      accessToken: data.access_token,
      expiresAt: new Date(Date.now() + data.expires_in * 1000),
    };
  }

  private async exchangeCodeForShortLivedToken(
    code: string,
  ): Promise<ThreadsShortLivedTokenResponse> {
    const body = new URLSearchParams({
      client_id: this.configService.getOrThrow<string>('THREADS_CLIENT_ID'),
      client_secret: this.configService.getOrThrow<string>('THREADS_CLIENT_SECRET'),
      grant_type: 'authorization_code',
      redirect_uri: this.configService.getOrThrow<string>('THREADS_REDIRECT_URI'),
      code,
    });

    const response = await fetch(TOKEN_URL, { method: 'POST', body });

    if (!response.ok) {
      throw new Error(
        `Threads code exchange failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as ThreadsShortLivedTokenResponse;
    if (!data.access_token) {
      throw new Error('Threads code exchange returned no access token.');
    }
    return data;
  }

  private async exchangeForLongLivedToken(
    shortLivedToken: string,
  ): Promise<ThreadsLongLivedTokenResponse> {
    const params = new URLSearchParams({
      grant_type: 'th_exchange_token',
      client_secret: this.configService.getOrThrow<string>('THREADS_CLIENT_SECRET'),
      access_token: shortLivedToken,
    });

    const response = await fetch(`${LONG_LIVED_TOKEN_URL}?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Threads long-lived token exchange failed: ${response.status} ${await response.text()}`,
      );
    }

    return (await response.json()) as ThreadsLongLivedTokenResponse;
  }

  private async fetchProfile(accessToken: string): Promise<ThreadsProfileResponse> {
    const params = new URLSearchParams({
      fields: 'id,username',
      access_token: accessToken,
    });

    const response = await fetch(`${API_BASE}/me?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Threads profile fetch failed: ${response.status} ${await response.text()}`,
      );
    }

    return (await response.json()) as ThreadsProfileResponse;
  }

  /**
   * Two-step publish, the same shape as Instagram's: create an image
   * container describing the post, then publish that container. Threads
   * fetches the image from `imageUrl` rather than accepting a binary
   * upload, so the URL must be publicly reachable (the reason Cloudinary
   * is in the pipeline).
   *
   * No internal retry between the two steps — see the interface's
   * publish() contract and the media-processing note on the class.
   */
  async publish(request: PublishRequest): Promise<PublishResult> {
    const creationId = await this.createMediaContainer(request);
    return { externalPostId: await this.publishContainer(request, creationId) };
  }

  private async createMediaContainer(request: PublishRequest): Promise<string> {
    const body = new URLSearchParams({
      media_type: 'IMAGE',
      image_url: request.imageUrl,
      text: request.caption,
      access_token: request.accessToken,
    });

    const response = await fetch(`${API_BASE}/${request.externalAccountId}/threads`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });

    if (!response.ok) {
      throw new Error(
        `Threads media container creation failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as { id?: string };
    if (!data.id) {
      throw new Error('Threads returned no container id.');
    }
    return data.id;
  }

  private async publishContainer(
    request: PublishRequest,
    creationId: string,
  ): Promise<string> {
    const body = new URLSearchParams({
      creation_id: creationId,
      access_token: request.accessToken,
    });

    const response = await fetch(
      `${API_BASE}/${request.externalAccountId}/threads_publish`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body,
      },
    );

    if (!response.ok) {
      throw new Error(
        `Threads publish failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as { id?: string };
    if (!data.id) {
      throw new Error('Threads returned no post id.');
    }
    return data.id;
  }

  async publishCarousel(
    request: CarouselPublishRequest,
  ): Promise<PublishResult> {
    // Threads carousel: an item container per image (is_carousel_item), a
    // parent CAROUSEL container, then threads_publish on the parent.
    const childIds: string[] = [];
    for (const imageUrl of request.mediaUrls) {
      childIds.push(await this.createCarouselItem(request, imageUrl));
    }
    const parentId = await this.createCarouselContainer(request, childIds);
    return {
      externalPostId: await this.publishCreationId(request, parentId),
    };
  }

  private async createCarouselItem(
    request: CarouselPublishRequest,
    imageUrl: string,
  ): Promise<string> {
    const body = new URLSearchParams({
      media_type: 'IMAGE',
      image_url: imageUrl,
      is_carousel_item: 'true',
      access_token: request.accessToken,
    });
    const response = await fetch(
      `${API_BASE}/${request.externalAccountId}/threads`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body,
      },
    );
    if (!response.ok) {
      throw new Error(
        `Threads carousel item creation failed: ${response.status} ${await response.text()}`,
      );
    }
    const data = (await response.json()) as { id?: string };
    if (!data.id) throw new Error('Threads returned no carousel item id.');
    return data.id;
  }

  private async createCarouselContainer(
    request: CarouselPublishRequest,
    childIds: string[],
  ): Promise<string> {
    const body = new URLSearchParams({
      media_type: 'CAROUSEL',
      children: childIds.join(','),
      text: request.caption,
      access_token: request.accessToken,
    });
    const response = await fetch(
      `${API_BASE}/${request.externalAccountId}/threads`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body,
      },
    );
    if (!response.ok) {
      throw new Error(
        `Threads carousel container creation failed: ${response.status} ${await response.text()}`,
      );
    }
    const data = (await response.json()) as { id?: string };
    if (!data.id) throw new Error('Threads returned no carousel container id.');
    return data.id;
  }

  private async publishCreationId(
    request: CarouselPublishRequest,
    creationId: string,
  ): Promise<string> {
    const body = new URLSearchParams({
      creation_id: creationId,
      access_token: request.accessToken,
    });
    const response = await fetch(
      `${API_BASE}/${request.externalAccountId}/threads_publish`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body,
      },
    );
    if (!response.ok) {
      throw new Error(
        `Threads publish failed: ${response.status} ${await response.text()}`,
      );
    }
    const data = (await response.json()) as { id?: string };
    if (!data.id) throw new Error('Threads returned no post id.');
    return data.id;
  }
}
