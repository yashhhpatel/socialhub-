/**
 * Contract every social platform integration implements. Per
 * docs/api/SocialHub_REST_API_Design.md §4: every adapter must expose a
 * capabilities() contract so the editor and scheduler can validate
 * BEFORE attempting to publish, not after a failure.
 *
 * SCOPE NOTE: this milestone's file list is "Files/folders modified:
 * none" — schema.prisma is not touched here, so there is no Prisma
 * `Platform` enum yet (that arrives in Milestone 2.2 alongside the
 * SocialAccount model). PlatformName below is this file's own type,
 * not a re-export of a Prisma enum that doesn't exist yet. When 2.2
 * introduces the real Platform enum, its values are defined to match
 * these exact strings — so adapters constructed against PlatformName
 * now need no translation layer later, just an import swap.
 *
 * SCOPE NOTE: no publish()/OAuth-callback-handling methods yet. Per the
 * blueprint, those are what Milestones 2.2/2.3 (Instagram/X OAuth) and
 * 4.2 (synchronous publish) actually need — adding them speculatively
 * now, before any adapter implements them, would be an interface nobody
 * can verify is even shaped correctly yet.
 */

export type PlatformName = 'instagram' | 'facebook' | 'threads' | 'x' | 'linkedin';

export type PlatformMediaType = 'image' | 'video';

export interface PlatformRateLimit {
  requests: number;
  windowSeconds: number;
}

export interface PlatformCapabilities {
  supportedMediaTypes: PlatformMediaType[];
  maxCaptionLength: number;
  /** Undefined for platforms with no video support at all. */
  maxVideoDurationSeconds?: number;
  rateLimit: PlatformRateLimit;
}

/** Result of completing an OAuth authorization-code exchange. */
export interface OAuthConnectionResult {
  externalAccountId: string;
  accessToken: string;
  /** Not every platform issues a refresh token (see each adapter). */
  refreshToken?: string;
  expiresAt?: Date;
}

/** Result of refreshing an expiring/expired access token. */
export interface RefreshedTokens {
  accessToken: string;
  refreshToken?: string;
  expiresAt?: Date;
}

export interface PlatformAdapter {
  readonly platform: PlatformName;

  /**
   * Static, platform-specific limits. Deliberately synchronous and
   * side-effect-free — this is metadata about the platform itself, not
   * a network call, so callers (editor preview, scheduler validation)
   * can use it freely without worrying about latency or failure modes.
   */
  capabilities(): PlatformCapabilities;

  /**
   * Builds the URL the user is redirected to in order to grant access.
   * `state` is an opaque, caller-generated anti-CSRF token the adapter
   * must round-trip unmodified — verifying it on the callback is the
   * caller's responsibility, not the adapter's.
   */
  getAuthorizationUrl(state: string): string;

  /**
   * Exchanges an OAuth authorization code (received on the callback
   * route) for real tokens.
   */
  connect(authorizationCode: string): Promise<OAuthConnectionResult>;

  /**
   * Exchanges a refresh token for a new access token. Throws if the
   * platform rejects it (revoked, expired past the point of no return,
   * etc.) — callers are expected to mark the connection's status
   * accordingly, not retry blindly.
   */
  refresh(refreshToken: string): Promise<RefreshedTokens>;
}
