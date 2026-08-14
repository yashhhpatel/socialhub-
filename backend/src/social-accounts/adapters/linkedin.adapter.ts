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

const AUTHORIZE_URL = 'https://www.linkedin.com/oauth/v2/authorization';
const TOKEN_URL = 'https://www.linkedin.com/oauth/v2/accessToken';
const USERINFO_URL = 'https://api.linkedin.com/v2/userinfo';
const REST_BASE = 'https://api.linkedin.com/rest';

// LinkedIn's versioned REST API requires a LinkedIn-Version header in
// YYYYMM form. These calendars expire (~12 months), so this constant is
// the single place to bump when LinkedIn retires the pinned version — the
// alternative, an unversioned call, is rejected outright.
const LINKEDIN_VERSION = '202401';

// openid/profile: identify the member (OpenID Connect userinfo -> `sub`).
// w_member_social: the scope that actually authorizes posting on their
// behalf. Requested together so the one-time consent covers publishing.
const SCOPES = ['openid', 'profile', 'w_member_social'];

interface LinkedInTokenResponse {
  access_token: string;
  expires_in: number; // seconds (~60 days)
  // Only issued to approved apps (Marketing Developer Platform); absent for
  // most apps, in which case the member re-authorizes when the token lapses.
  refresh_token?: string;
  refresh_token_expires_in?: number;
  scope: string;
  token_type: string;
}

interface LinkedInUserInfo {
  sub: string; // the member id; the author URN is urn:li:person:{sub}
  name?: string;
}

/**
 * Publishes to LinkedIn as a member via LinkedIn's current (2026) OAuth
 * 2.0 + OpenID Connect and versioned Posts REST API — verified against
 * the docs before writing this. Unlike the other four adapters this is not
 * a Meta/X property, and it differs in two concrete ways worth knowing:
 *
 * 1. IDENTITY comes from OpenID Connect: connect() reads /v2/userinfo and
 *    stores the `sub` claim as externalAccountId. The author of a post is
 *    the URN `urn:li:person:{sub}`.
 *
 * 2. PUBLISH is three calls, and the created post's id comes back in a
 *    RESPONSE HEADER (`x-restli-id`), not the body: (a) initialize an
 *    image upload to get a one-time upload URL + an image URN, (b) PUT the
 *    image bytes to that URL, (c) create the post referencing the image
 *    URN. LinkedIn will not fetch the image from a URL the way Instagram
 *    does, so — like X — the bytes are downloaded from Cloudinary and
 *    re-uploaded.
 *
 * This is a confidential client (it holds a client secret), so the plain
 * authorization-code flow is used without PKCE — LinkedIn supports PKCE
 * but does not require it here, and skipping it keeps the service wiring
 * identical to the other non-PKCE adapters.
 *
 * TOKEN NOTE: refresh tokens are only issued to approved apps. connect()
 * passes one through when present; when absent, refresh() cannot run and
 * the member re-authorizes on expiry — the honest behaviour rather than
 * pretending a refresh path exists.
 *
 * Uses Node's built-in global fetch, like the other adapters.
 */
@Injectable()
export class LinkedInAdapter implements PlatformAdapter {
  readonly platform: PlatformName = 'linkedin';

  constructor(private readonly configService: ConfigService) {}

  capabilities(): PlatformCapabilities {
    return {
      supportedMediaTypes: ['image', 'video'],
      maxCaptionLength: 3000, // LinkedIn's post commentary limit
      maxVideoDurationSeconds: 1800, // 30 minutes
      imageSpec: {
        // 1.91:1 — LinkedIn's recommended shared-image ratio, so a
        // rendition displays in-feed without being re-cropped.
        width: 1200,
        height: 627,
        aspectRatio: '1.91:1',
      },
      rateLimit: {
        // Conservative placeholder for pre-flight UI warnings — LinkedIn
        // enforces both per-app and per-member throttles that this adapter
        // can't see; the real ceiling depends on the app's tier.
        requests: 100,
        windowSeconds: 86400,
      },
    };
  }

  getAuthorizationUrl(state: string): string {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.configService.getOrThrow<string>('LINKEDIN_CLIENT_ID'),
      redirect_uri: this.configService.getOrThrow<string>('LINKEDIN_REDIRECT_URI'),
      scope: SCOPES.join(' '),
      state,
    });

    return `${AUTHORIZE_URL}?${params.toString()}`;
  }

  async connect(authorizationCode: string): Promise<OAuthConnectionResult> {
    const tokens = await this.exchangeCodeForTokens(authorizationCode);
    const profile = await this.fetchProfile(tokens.access_token);

    return {
      externalAccountId: profile.sub,
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
      expiresAt: new Date(Date.now() + tokens.expires_in * 1000),
    };
  }

  async refresh(refreshToken: string): Promise<RefreshedTokens> {
    const body = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: this.configService.getOrThrow<string>('LINKEDIN_CLIENT_ID'),
      client_secret: this.configService.getOrThrow<string>('LINKEDIN_CLIENT_SECRET'),
    });

    const response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });

    if (!response.ok) {
      throw new Error(
        `LinkedIn token refresh failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as LinkedInTokenResponse;

    return {
      accessToken: data.access_token,
      // LinkedIn rotates the refresh token on use, like X — persist the new
      // one rather than assuming the original stays valid.
      refreshToken: data.refresh_token,
      expiresAt: new Date(Date.now() + data.expires_in * 1000),
    };
  }

  private async exchangeCodeForTokens(code: string): Promise<LinkedInTokenResponse> {
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: this.configService.getOrThrow<string>('LINKEDIN_REDIRECT_URI'),
      client_id: this.configService.getOrThrow<string>('LINKEDIN_CLIENT_ID'),
      client_secret: this.configService.getOrThrow<string>('LINKEDIN_CLIENT_SECRET'),
    });

    const response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });

    if (!response.ok) {
      throw new Error(
        `LinkedIn code exchange failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as LinkedInTokenResponse;
    if (!data.access_token) {
      throw new Error('LinkedIn code exchange returned no access token.');
    }
    return data;
  }

  private async fetchProfile(accessToken: string): Promise<LinkedInUserInfo> {
    const response = await fetch(USERINFO_URL, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!response.ok) {
      throw new Error(
        `LinkedIn profile fetch failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as LinkedInUserInfo;
    if (!data.sub) {
      throw new Error('LinkedIn userinfo returned no member id.');
    }
    return data;
  }

  /**
   * Three-call publish: initialize an image upload, PUT the bytes, then
   * create the post referencing the returned image URN. The created post's
   * id arrives in the `x-restli-id` response header, not the body.
   *
   * No internal retry — see the interface's publish() contract. A retry
   * after an ambiguous timeout on the create-post step would double-post.
   */
  async publish(request: PublishRequest): Promise<PublishResult> {
    const author = `urn:li:person:${request.externalAccountId}`;
    const { uploadUrl, imageUrn } = await this.initializeImageUpload(author, request.accessToken);
    await this.uploadImageBytes(uploadUrl, request);
    return { externalPostId: await this.createPost(author, imageUrn, request) };
  }

  private restHeaders(accessToken: string): Record<string, string> {
    return {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'LinkedIn-Version': LINKEDIN_VERSION,
      'X-Restli-Protocol-Version': '2.0.0',
    };
  }

  private async initializeImageUpload(
    author: string,
    accessToken: string,
  ): Promise<{ uploadUrl: string; imageUrn: string }> {
    const response = await fetch(`${REST_BASE}/images?action=initializeUpload`, {
      method: 'POST',
      headers: this.restHeaders(accessToken),
      body: JSON.stringify({ initializeUploadRequest: { owner: author } }),
    });

    if (!response.ok) {
      throw new Error(
        `LinkedIn image upload init failed: ${response.status} ${await response.text()}`,
      );
    }

    const data = (await response.json()) as {
      value?: { uploadUrl?: string; image?: string };
    };
    const uploadUrl = data.value?.uploadUrl;
    const imageUrn = data.value?.image;
    if (!uploadUrl || !imageUrn) {
      throw new Error('LinkedIn image upload init returned no upload URL.');
    }
    return { uploadUrl, imageUrn };
  }

  private async uploadImageBytes(
    uploadUrl: string,
    request: PublishRequest,
  ): Promise<void> {
    const imageResponse = await fetch(request.imageUrl);
    if (!imageResponse.ok) {
      throw new Error(
        `Could not fetch the rendered image for upload: ${imageResponse.status}`,
      );
    }
    const bytes = await imageResponse.arrayBuffer();

    const response = await fetch(uploadUrl, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${request.accessToken}` },
      body: bytes,
    });

    if (!response.ok) {
      throw new Error(
        `LinkedIn image upload failed: ${response.status} ${await response.text()}`,
      );
    }
  }

  private async createPost(
    author: string,
    imageUrn: string,
    request: PublishRequest,
  ): Promise<string> {
    const response = await fetch(`${REST_BASE}/posts`, {
      method: 'POST',
      headers: this.restHeaders(request.accessToken),
      body: JSON.stringify({
        author,
        commentary: request.caption,
        visibility: 'PUBLIC',
        distribution: {
          feedDistribution: 'MAIN_FEED',
          targetEntities: [],
          thirdPartyDistributionChannels: [],
        },
        content: { media: { id: imageUrn, title: 'image' } },
        lifecycleState: 'PUBLISHED',
        isReshareDisabledByAuthor: false,
      }),
    });

    if (!response.ok) {
      throw new Error(
        `LinkedIn publish failed: ${response.status} ${await response.text()}`,
      );
    }

    // The created post's URN is returned in a header, not the body.
    const postId = response.headers.get('x-restli-id') ?? response.headers.get('x-linkedin-id');
    if (!postId) {
      throw new Error('LinkedIn returned no post id.');
    }
    return postId;
  }
}
