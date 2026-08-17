import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  OAuthConnectionResult,
  PublishRequest,
  PublishResult,
  PlatformAdapter,
  PlatformCapabilities,
  PlatformName,
  RefreshedTokens,
} from './adapter.interface';

const GRAPH_VERSION = 'v21.0';
const AUTHORIZE_URL = `https://www.facebook.com/${GRAPH_VERSION}/dialog/oauth`;
const GRAPH_BASE = `https://graph.facebook.com/${GRAPH_VERSION}`;
const TOKEN_URL = `${GRAPH_BASE}/oauth/access_token`;
const ACCOUNTS_URL = `${GRAPH_BASE}/me/accounts`;

// Publishing to a Page needs the Page-management scopes; pages_show_list is
// what lets us enumerate the Pages the user administers to pick one to
// publish as. public_profile is granted by default but requested explicitly
// so the consent screen is unambiguous.
const SCOPES = [
  'public_profile',
  'pages_show_list',
  'pages_read_engagement',
  'pages_manage_posts',
];

interface FacebookTokenResponse {
  access_token: string;
  token_type: string;
  // Present on the long-lived exchange; short-lived user tokens omit it.
  expires_in?: number; // seconds
}

interface FacebookAccountsResponse {
  data: Array<{
    id: string; // the Page id
    name: string;
    access_token: string; // the Page access token
  }>;
}

/**
 * Publishes to a Facebook Page via Meta's current (2026) Graph API —
 * verified against the Pages publishing docs before writing this.
 *
 * The connect flow has an extra hop the other adapters don't: Facebook
 * OAuth yields a *user* token, but you cannot post to a Page with a user
 * token — you post with a *Page* access token, fetched from
 * `/me/accounts`. So connect() exchanges the code for a user token,
 * upgrades it to long-lived, then reads the first Page the user
 * administers and stores THAT Page's id + Page token. `externalAccountId`
 * is therefore a Page id, and `accessToken` is a Page token — which is
 * what publish() needs.
 *
 * MULTI-PAGE NOTE: a user may administer several Pages; this takes the
 * first one, mirroring how the Instagram adapter takes the single business
 * profile. A Page picker is a reasonable future enhancement (it belongs in
 * the connect UI, not here), not something this milestone needs.
 *
 * TOKEN LIFETIME NOTE: a Page access token derived from a long-lived user
 * token does not itself expire as long as the user token stays valid, so
 * Facebook has no separate refresh-token grant. refresh() re-runs the
 * long-lived exchange in place (fb_exchange_token), the same in-place model
 * the Instagram adapter documents — see the note there.
 *
 * Uses Node's built-in global fetch, like the other adapters.
 */
@Injectable()
export class FacebookAdapter implements PlatformAdapter {
  readonly platform: PlatformName = 'facebook';

  constructor(private readonly configService: ConfigService) {}

  // Meta's dashboard labels these the "App ID" and "App Secret", so
  // FACEBOOK_APP_ID / FACEBOOK_APP_SECRET is the natural thing to put in
  // .env — accept those first, falling back to the older *_CLIENT_* names so
  // existing configs keep working. getOrThrow on the fallback preserves the
  // clear "not configured" error when neither is set.
  private clientId(): string {
    return (
      this.configService.get<string>('FACEBOOK_APP_ID') ??
      this.configService.getOrThrow<string>('FACEBOOK_CLIENT_ID')
    );
  }

  private clientSecret(): string {
    return (
      this.configService.get<string>('FACEBOOK_APP_SECRET') ??
      this.configService.getOrThrow<string>('FACEBOOK_CLIENT_SECRET')
    );
  }

  capabilities(): PlatformCapabilities {
    return {
      supportedMediaTypes: ['image', 'video'],
      // Facebook's caption ceiling is enormous (63,206 chars) — kept as the
      // documented hard limit so pre-flight validation never rejects a
      // caption the platform would actually accept.
      maxCaptionLength: 63206,
      maxVideoDurationSeconds: 14400, // 240 minutes, the Page video ceiling
      imageSpec: {
        // 1.91:1 — the ratio Facebook itself recommends for a feed image, so
        // a rendition at this size displays without the Page feed re-cropping
        // it.
        width: 1200,
        height: 630,
        aspectRatio: '1.91:1',
      },
      rateLimit: {
        // Business Use Case rate limiting, same family as Instagram's
        // published 200-calls/hour figure.
        requests: 200,
        windowSeconds: 3600,
      },
    };
  }

  getAuthorizationUrl(state: string): string {
    const params = new URLSearchParams({
      client_id: this.clientId(),
      redirect_uri: this.configService.getOrThrow<string>('FACEBOOK_REDIRECT_URI'),
      response_type: 'code',
      scope: SCOPES.join(','),
      state,
    });

    return `${AUTHORIZE_URL}?${params.toString()}`;
  }

  async connect(authorizationCode: string): Promise<OAuthConnectionResult> {
    const userToken = await this.exchangeCodeForUserToken(authorizationCode);
    const longLived = await this.exchangeForLongLivedToken(userToken);
    const page = await this.fetchFirstPage(longLived.access_token);

    return {
      externalAccountId: page.id,
      // The PAGE token, not the user token — this is what publish() posts
      // with. See class doc comment.
      accessToken: page.access_token,
      // No separate refresh token — see class doc comment. expiresIn is on
      // the user token; the derived Page token tracks its validity.
      expiresAt: longLived.expires_in
        ? new Date(Date.now() + longLived.expires_in * 1000)
        : undefined,
    };
  }

  async refresh(refreshToken: string): Promise<RefreshedTokens> {
    // `refreshToken` here is the current long-lived user/page token — see
    // class doc comment on the in-place refresh model.
    const longLived = await this.exchangeForLongLivedToken(refreshToken);
    return {
      accessToken: longLived.access_token,
      expiresAt: longLived.expires_in
        ? new Date(Date.now() + longLived.expires_in * 1000)
        : undefined,
    };
  }

  private async exchangeCodeForUserToken(code: string): Promise<string> {
    const params = new URLSearchParams({
      client_id: this.clientId(),
      client_secret: this.clientSecret(),
      redirect_uri: this.configService.getOrThrow<string>('FACEBOOK_REDIRECT_URI'),
      code,
    });

    const response = await fetch(`${TOKEN_URL}?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Facebook code exchange failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as FacebookTokenResponse;
    if (!data.access_token) {
      throw new Error('Facebook code exchange returned no access token.');
    }
    return data.access_token;
  }

  private async exchangeForLongLivedToken(
    shortLivedToken: string,
  ): Promise<FacebookTokenResponse> {
    const params = new URLSearchParams({
      grant_type: 'fb_exchange_token',
      client_id: this.clientId(),
      client_secret: this.clientSecret(),
      fb_exchange_token: shortLivedToken,
    });

    const response = await fetch(`${TOKEN_URL}?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Facebook long-lived token exchange failed: ${response.status} ${await response.text()}`,
      );
    }

    return (await response.json()) as FacebookTokenResponse;
  }

  private async fetchFirstPage(
    userAccessToken: string,
  ): Promise<{ id: string; access_token: string }> {
    const params = new URLSearchParams({
      fields: 'id,name,access_token',
      access_token: userAccessToken,
    });

    const response = await fetch(`${ACCOUNTS_URL}?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Facebook page lookup failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as FacebookAccountsResponse;
    const page = data.data?.[0];
    if (!page?.id || !page.access_token) {
      throw new Error(
        'No Facebook Page found for this account. Connect an account that administers at least one Page.',
      );
    }
    return { id: page.id, access_token: page.access_token };
  }

  /**
   * Publishes a photo to the Page. Like Instagram, Facebook fetches the
   * image from a URL rather than accepting a binary upload here, so
   * `imageUrl` must be publicly reachable (the reason Cloudinary is in the
   * pipeline). A single POST to `/{page-id}/photos` with `url` + `caption`
   * both uploads and publishes — no separate container step, unlike
   * Instagram.
   *
   * No internal retry — see the interface's publish() contract. A retry
   * after an ambiguous timeout would double-post.
   */
  async publish(request: PublishRequest): Promise<PublishResult> {
    const body = new URLSearchParams({
      url: request.imageUrl,
      caption: request.caption,
      access_token: request.accessToken,
    });

    const response = await fetch(`${GRAPH_BASE}/${request.externalAccountId}/photos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });

    if (!response.ok) {
      throw new Error(
        `Facebook publish failed: ${response.status} ${await response.text()}`,
      );
    }

    // A photo post returns { id, post_id }; post_id is the feed story we
    // want as the join key, but older responses only carry id — accept
    // whichever is present.
    const data = (await response.json()) as { id?: string; post_id?: string };
    const postId = data.post_id ?? data.id;
    if (!postId) {
      throw new Error('Facebook returned no post id.');
    }
    return { externalPostId: postId };
  }
}
