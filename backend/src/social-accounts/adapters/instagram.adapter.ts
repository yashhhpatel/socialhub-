import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  OAuthConnectionResult,
  PlatformAdapter,
  PlatformCapabilities,
  PlatformName,
  RefreshedTokens,
} from './adapter.interface';

const AUTHORIZE_URL = 'https://www.instagram.com/oauth/authorize';
const TOKEN_URL = 'https://api.instagram.com/oauth/access_token';
const LONG_LIVED_TOKEN_URL = 'https://graph.instagram.com/access_token';
const REFRESH_URL = 'https://graph.instagram.com/refresh_access_token';
const PROFILE_URL = 'https://graph.instagram.com/me';

// instagram_business_basic: read profile/media.
// instagram_business_content_publish: required for Phase 4/7's publish
// flow later — requested now so the one-time OAuth consent screen the
// user sees already covers it; re-requesting scopes later would mean
// asking them to reconnect.
const SCOPES = ['instagram_business_basic', 'instagram_business_content_publish'];

interface InstagramShortLivedTokenResponse {
  data: Array<{ access_token: string; user_id: string; permissions: string }>;
}

interface InstagramLongLivedTokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number; // seconds
}

interface InstagramProfileResponse {
  id: string;
  username: string;
}

/**
 * Implements docs/api adapter contract via Meta's current (2026)
 * "Business Login for Instagram" flow — see
 * https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/business-login.
 * The old Instagram Basic Display API this might once have used was
 * fully shut down December 4, 2024; this is not that.
 *
 * PLATFORM QUIRK worth knowing: Instagram doesn't have a distinct OAuth
 * "refresh token" the way this interface's method name implies for other
 * platforms. Instead, the SAME long-lived access token is itself
 * refreshed/extended in place. So refresh()'s `refreshToken` parameter
 * here actually receives the current long-lived ACCESS token, not a
 * separate refresh token — SocialAccountsService must pass the right
 * thing when calling this. Documented here and at the call site.
 *
 * Uses Node's built-in global fetch (stable since Node 18) rather than
 * adding an HTTP client dependency for one adapter.
 */
@Injectable()
export class InstagramAdapter implements PlatformAdapter {
  readonly platform: PlatformName = 'instagram';

  constructor(private readonly configService: ConfigService) {}

  capabilities(): PlatformCapabilities {
    return {
      supportedMediaTypes: ['image', 'video'],
      maxCaptionLength: 2200,
      maxVideoDurationSeconds: 900, // Reels; feed video limits are shorter but this is the ceiling
      rateLimit: {
        // Business Use Case rate limit: 200 calls/hour per user, per
        // Meta's current published limit.
        requests: 200,
        windowSeconds: 3600,
      },
    };
  }

  getAuthorizationUrl(state: string): string {
    const params = new URLSearchParams({
      client_id: this.configService.getOrThrow<string>('INSTAGRAM_CLIENT_ID'),
      redirect_uri: this.configService.getOrThrow<string>('INSTAGRAM_REDIRECT_URI'),
      response_type: 'code',
      scope: SCOPES.join(','),
      state,
    });

    return `${AUTHORIZE_URL}?${params.toString()}`;
  }

  async connect(authorizationCode: string): Promise<OAuthConnectionResult> {
    const shortLivedToken = await this.exchangeCodeForShortLivedToken(authorizationCode);
    const longLived = await this.exchangeForLongLivedToken(shortLivedToken);
    const profile = await this.fetchProfile(longLived.access_token);

    return {
      externalAccountId: profile.id,
      accessToken: longLived.access_token,
      // No separate refresh token for Instagram — see class doc comment.
      expiresAt: new Date(Date.now() + longLived.expires_in * 1000),
    };
  }

  async refresh(refreshToken: string): Promise<RefreshedTokens> {
    // `refreshToken` here is the current long-lived access token — see
    // class doc comment on why.
    const params = new URLSearchParams({
      grant_type: 'ig_refresh_token',
      access_token: refreshToken,
    });

    const response = await fetch(`${REFRESH_URL}?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Instagram token refresh failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as InstagramLongLivedTokenResponse;

    return {
      accessToken: data.access_token,
      expiresAt: new Date(Date.now() + data.expires_in * 1000),
    };
  }

  private async exchangeCodeForShortLivedToken(code: string): Promise<string> {
    const body = new URLSearchParams({
      client_id: this.configService.getOrThrow<string>('INSTAGRAM_CLIENT_ID'),
      client_secret: this.configService.getOrThrow<string>('INSTAGRAM_CLIENT_SECRET'),
      grant_type: 'authorization_code',
      redirect_uri: this.configService.getOrThrow<string>('INSTAGRAM_REDIRECT_URI'),
      code,
    });

    const response = await fetch(TOKEN_URL, { method: 'POST', body });

    if (!response.ok) {
      throw new Error(
        `Instagram code exchange failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as InstagramShortLivedTokenResponse;
    const token = data.data?.[0]?.access_token;

    if (!token) {
      throw new Error('Instagram code exchange returned no access token.');
    }

    return token;
  }

  private async exchangeForLongLivedToken(
    shortLivedToken: string,
  ): Promise<InstagramLongLivedTokenResponse> {
    const params = new URLSearchParams({
      grant_type: 'ig_exchange_token',
      client_secret: this.configService.getOrThrow<string>('INSTAGRAM_CLIENT_SECRET'),
      access_token: shortLivedToken,
    });

    const response = await fetch(`${LONG_LIVED_TOKEN_URL}?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Instagram long-lived token exchange failed: ${response.status} ${await response.text()}`,
      );
    }

    return (await response.json()) as InstagramLongLivedTokenResponse;
  }

  private async fetchProfile(accessToken: string): Promise<InstagramProfileResponse> {
    const params = new URLSearchParams({
      fields: 'id,username',
      access_token: accessToken,
    });

    const response = await fetch(`${PROFILE_URL}?${params.toString()}`);

    if (!response.ok) {
      throw new Error(
        `Instagram profile fetch failed: ${response.status} ${await response.text()}`,
      );
    }

    return (await response.json()) as InstagramProfileResponse;
  }
}
