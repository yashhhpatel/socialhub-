import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  OAuthConnectionResult,
  PlatformAdapter,
  PlatformCapabilities,
  PlatformName,
  RefreshedTokens,
} from './adapter.interface';

const AUTHORIZE_URL = 'https://x.com/i/oauth2/authorize';
const TOKEN_URL = 'https://api.x.com/2/oauth2/token';
const ME_URL = 'https://api.x.com/2/users/me';

// offline.access is required to receive a refresh_token at all — without
// it, the access token simply expires after 2 hours with no way to renew
// short of the user re-authorizing.
const SCOPES = ['tweet.read', 'tweet.write', 'users.read', 'offline.access'];

interface XTokenResponse {
  token_type: string;
  expires_in: number; // seconds; access tokens are short-lived (2h) on X
  access_token: string;
  scope: string;
  refresh_token?: string;
}

interface XUserResponse {
  data: { id: string; username: string; name: string };
}

/**
 * Implements the PlatformAdapter contract via X's current OAuth 2.0 +
 * PKCE flow — verified against current (2026) X API documentation before
 * writing this. Requires PKCE, unlike Instagram's adapter (Milestone
 * 2.2) — see adapter.interface.ts's PKCE NOTE for how that's threaded
 * through without special-casing the interface for one platform.
 *
 * Uses HTTP Basic Auth (client_id:client_secret) for the token exchange,
 * the "confidential client" pattern appropriate for a server-side app
 * that can safely hold a client secret (as opposed to a "public client"
 * like a mobile app, which can't).
 *
 * RATE LIMIT NOTE: as of February 2026, X moved new developers to a
 * pay-per-use pricing model (credits, cost per call) rather than a flat
 * requests-per-window quota for many endpoints. This doesn't map cleanly
 * onto PlatformCapabilities.rateLimit's {requests, windowSeconds} shape,
 * which was designed around the older flat-quota model. The values below
 * are a conservative placeholder for pre-flight UI warnings, not an
 * authoritative limit — actual throttling depends on the connected
 * account's specific purchased tier/credit balance, which this adapter
 * has no visibility into. Flagged honestly rather than presented as
 * precise.
 */
@Injectable()
export class XAdapter implements PlatformAdapter {
  readonly platform: PlatformName = 'x';

  constructor(private readonly configService: ConfigService) {}

  capabilities(): PlatformCapabilities {
    return {
      supportedMediaTypes: ['image', 'video'],
      maxCaptionLength: 280, // free/basic tier; Pro tier allows up to 25,000
      maxVideoDurationSeconds: 140,
      rateLimit: {
        // See class doc comment — placeholder under the pay-per-use model.
        requests: 50,
        windowSeconds: 86400,
      },
    };
  }

  getAuthorizationUrl(state: string, codeChallenge?: string): string {
    if (!codeChallenge) {
      throw new Error('XAdapter.getAuthorizationUrl requires a PKCE codeChallenge.');
    }

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.configService.getOrThrow<string>('X_CLIENT_ID'),
      redirect_uri: this.configService.getOrThrow<string>('X_REDIRECT_URI'),
      scope: SCOPES.join(' '),
      state,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
    });

    return `${AUTHORIZE_URL}?${params.toString()}`;
  }

  async connect(
    authorizationCode: string,
    codeVerifier?: string,
  ): Promise<OAuthConnectionResult> {
    if (!codeVerifier) {
      throw new Error('XAdapter.connect requires a PKCE codeVerifier.');
    }

    const tokens = await this.exchangeCodeForTokens(authorizationCode, codeVerifier);
    const profile = await this.fetchProfile(tokens.access_token);

    return {
      externalAccountId: profile.data.id,
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
      expiresAt: new Date(Date.now() + tokens.expires_in * 1000),
    };
  }

  async refresh(refreshToken: string): Promise<RefreshedTokens> {
    const body = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: this.configService.getOrThrow<string>('X_CLIENT_ID'),
    });

    const response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: this.basicAuthHeader(),
      },
      body,
    });

    if (!response.ok) {
      throw new Error(`X token refresh failed: ${response.status} ${await response.text()}`);
    }

    const data = (await response.json()) as XTokenResponse;

    return {
      accessToken: data.access_token,
      // X rotates the refresh token on every use — the old one becomes
      // invalid, so the caller MUST persist this new one, not assume the
      // original refresh token stays valid indefinitely.
      refreshToken: data.refresh_token,
      expiresAt: new Date(Date.now() + data.expires_in * 1000),
    };
  }

  private async exchangeCodeForTokens(
    code: string,
    codeVerifier: string,
  ): Promise<XTokenResponse> {
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: this.configService.getOrThrow<string>('X_REDIRECT_URI'),
      code_verifier: codeVerifier,
    });

    const response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: this.basicAuthHeader(),
      },
      body,
    });

    if (!response.ok) {
      throw new Error(`X code exchange failed: ${response.status} ${await response.text()}`);
    }

    return (await response.json()) as XTokenResponse;
  }

  private async fetchProfile(accessToken: string): Promise<XUserResponse> {
    const response = await fetch(ME_URL, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!response.ok) {
      throw new Error(`X profile fetch failed: ${response.status} ${await response.text()}`);
    }

    return (await response.json()) as XUserResponse;
  }

  private basicAuthHeader(): string {
    const clientId = this.configService.getOrThrow<string>('X_CLIENT_ID');
    const clientSecret = this.configService.getOrThrow<string>('X_CLIENT_SECRET');
    return `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`;
  }
}
