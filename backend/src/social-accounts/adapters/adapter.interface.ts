/**
 * Contract every social platform integration implements. Per
 * docs/api/SocialHub_REST_API_Design.md §4: every adapter must expose a
 * capabilities() contract so the editor and scheduler can validate
 * BEFORE attempting to publish, not after a failure.
 *
 * PlatformName's values are defined to match the Prisma `Platform` enum
 * (schema.prisma, added Milestone 2.2) exactly — no translation layer
 * needed between the two.
 *
 * SCOPE NOTE: no publish() method yet — that's Milestone 4.2's job, once
 * something actually needs it.
 *
 * PKCE NOTE (added Milestone 2.3, for X): getAuthorizationUrl() and
 * connect() both gained an optional trailing parameter. Instagram's
 * existing adapter (Milestone 2.2) needed zero code changes for this —
 * TypeScript allows an implementing method to declare fewer parameters
 * than its interface, so InstagramAdapter's original
 * `getAuthorizationUrl(state: string): string` still satisfies this
 * interface unmodified. Only X's adapter uses the new parameters.
 */

export type PlatformName = 'instagram' | 'facebook' | 'threads' | 'x' | 'linkedin';

export type PlatformMediaType = 'image' | 'video';

export interface PlatformRateLimit {
  requests: number;
  windowSeconds: number;
}

/**
 * Target pixel dimensions for a published still image on this platform.
 *
 * Added in Milestone 4.1: variant generation needs to know what size to
 * render for each platform, and the capabilities() contract is already
 * the designated home for "static, platform-specific limits" — putting
 * dimensions anywhere else would mean two competing sources of truth for
 * what a platform accepts.
 *
 * One canonical size per platform, not a list of every permitted ratio.
 * Platforms accept several (Instagram alone takes 1:1, 4:5 and 1.91:1);
 * picking the single safest default keeps this milestone's scope to
 * "resize per platform spec" rather than a user-facing crop-ratio
 * chooser, which belongs with the publish preview UI in Milestone 4.3.
 */
export interface PlatformImageSpec {
  width: number;
  height: number;
  /** Human-readable, for previews and validation messages (e.g. '1:1'). */
  aspectRatio: string;
}

export interface PlatformCapabilities {
  supportedMediaTypes: PlatformMediaType[];
  maxCaptionLength: number;
  /** Undefined for platforms with no video support at all. */
  maxVideoDurationSeconds?: number;
  imageSpec: PlatformImageSpec;
  rateLimit: PlatformRateLimit;
}

/** Result of completing an OAuth authorization-code exchange. */
export interface OAuthConnectionResult {
  externalAccountId: string;
  /**
   * The platform *user* id of the authorizing person, when it differs from
   * externalAccountId (e.g. Facebook, where externalAccountId is a Page id).
   * Meta's deauthorize/data-deletion callbacks match on this. Omit for
   * platforms that don't send those callbacks.
   */
  externalUserId?: string;
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

/** What to publish: one rendered image plus its caption. */
export interface PublishRequest {
  /** Publicly-reachable URL of the platform-specific rendition. */
  imageUrl: string;
  caption: string;
  /** The platform's own id for the connected account. */
  externalAccountId: string;
  accessToken: string;
}

export interface PublishResult {
  /** The platform's id for the created post — the join key analytics
   * (Phase 10) uses to pull metrics back for it. */
  externalPostId: string;
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
   *
   * `codeChallenge` is only used by PKCE-based adapters (X) — the
   * caller is responsible for generating the PKCE verifier/challenge
   * pair (see common/crypto/pkce.util.ts) and remembering the verifier
   * (typically by embedding it in its own `state` payload) until the
   * later `connect()` call. Non-PKCE adapters (Instagram) ignore this
   * parameter entirely.
   */
  getAuthorizationUrl(state: string, codeChallenge?: string): string;

  /**
   * Exchanges an OAuth authorization code (received on the callback
   * route) for real tokens. `codeVerifier` is only required by
   * PKCE-based adapters (X) — must be the same verifier whose challenge
   * was passed to getAuthorizationUrl for this same flow.
   */
  connect(
    authorizationCode: string,
    codeVerifier?: string,
  ): Promise<OAuthConnectionResult>;

  /**
   * Exchanges a refresh token for a new access token. Throws if the
   * platform rejects it (revoked, expired past the point of no return,
   * etc.) — callers are expected to mark the connection's status
   * accordingly, not retry blindly.
   */
  refresh(refreshToken: string): Promise<RefreshedTokens>;

  /**
   * Publishes one rendition to the platform (Milestone 4.2 — the method
   * this interface's original scope note reserved).
   *
   * IRREVERSIBLE: a successful call creates a real, publicly visible post
   * on a real account. Implementations must not retry internally on an
   * ambiguous failure (a timeout after the post may already have been
   * created), because a blind retry double-posts. Retry policy belongs to
   * the caller, which can see the job's attempt history — and from
   * Phase 7, to the queue.
   *
   * Throws on failure with the platform's own error text preserved.
   * Callers record that verbatim on the job's lastError: a platform
   * rejection ("caption too long", "media not reachable") is the only
   * thing that tells a user what to actually change.
   */
  publish(request: PublishRequest): Promise<PublishResult>;
}
