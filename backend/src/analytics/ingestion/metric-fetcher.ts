import { Injectable } from '@nestjs/common';
import { Platform } from '@prisma/client';

const IG_GRAPH_BASE = 'https://graph.instagram.com';
const X_API_BASE = 'https://api.x.com/2';
const FB_GRAPH_VERSION = 'v21.0';
const FB_GRAPH_BASE = `https://graph.facebook.com/${FB_GRAPH_VERSION}`;
const THREADS_API_BASE = 'https://graph.threads.net/v1.0';
const LINKEDIN_REST_BASE = 'https://api.linkedin.com/rest';
const LINKEDIN_VERSION = '202401';

// The Instagram media-insight metrics we map into CanonicalMetrics. Kept
// narrow on purpose — requesting a metric the media type doesn't support
// makes the whole call 400, so we ask only for the widely-supported ones.
const IG_METRICS = ['impressions', 'reach', 'likes', 'comments', 'shares'];
const THREADS_METRICS = ['views', 'likes', 'replies', 'reposts', 'quotes'];

/**
 * Pulls one published post's raw insights payload from its platform
 * (Phase 10). Returns the platform's response untouched — turning it into
 * canonical numbers is metric-normalization.ts's job, kept separate so the
 * mapping can be unit-tested without any network.
 *
 * Uses Node's built-in fetch, like the platform adapters. All five
 * platforms are wired (10.1 Instagram + X, 10.2 the rest); a per-post fetch
 * failure is recorded by the ingestion service, never aborting the run.
 */
@Injectable()
export class MetricFetcher {
  async fetchRaw(
    platform: Platform,
    externalPostId: string,
    accessToken: string,
  ): Promise<unknown> {
    switch (platform) {
      case Platform.instagram:
        return this.fetchInstagram(externalPostId, accessToken);
      case Platform.x:
        return this.fetchX(externalPostId, accessToken);
      case Platform.facebook:
        return this.fetchFacebook(externalPostId, accessToken);
      case Platform.threads:
        return this.fetchThreads(externalPostId, accessToken);
      case Platform.linkedin:
        return this.fetchLinkedIn(externalPostId, accessToken);
    }
  }

  private async fetchInstagram(mediaId: string, accessToken: string): Promise<unknown> {
    const params = new URLSearchParams({
      metric: IG_METRICS.join(','),
      access_token: accessToken,
    });
    const response = await fetch(`${IG_GRAPH_BASE}/${mediaId}/insights?${params.toString()}`);
    if (!response.ok) {
      throw new Error(
        `Instagram insights fetch failed: ${response.status} ${await response.text()}`,
      );
    }
    return response.json();
  }

  private async fetchX(tweetId: string, accessToken: string): Promise<unknown> {
    const response = await fetch(
      `${X_API_BASE}/tweets/${tweetId}?tweet.fields=public_metrics`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    if (!response.ok) {
      throw new Error(`X metrics fetch failed: ${response.status} ${await response.text()}`);
    }
    return response.json();
  }

  /**
   * Facebook needs insights (impressions/reach) and the object's own
   * engagement summaries in one request — fields=insights(...) plus
   * likes/comments/shares summaries — which normalizeFacebook maps together.
   */
  private async fetchFacebook(postId: string, accessToken: string): Promise<unknown> {
    const params = new URLSearchParams({
      fields:
        'insights.metric(post_impressions,post_impressions_unique,post_clicks){name,values},likes.summary(true),comments.summary(true),shares',
      access_token: accessToken,
    });
    const response = await fetch(`${FB_GRAPH_BASE}/${postId}?${params.toString()}`);
    if (!response.ok) {
      throw new Error(
        `Facebook insights fetch failed: ${response.status} ${await response.text()}`,
      );
    }
    return response.json();
  }

  private async fetchThreads(mediaId: string, accessToken: string): Promise<unknown> {
    const params = new URLSearchParams({
      metric: THREADS_METRICS.join(','),
      access_token: accessToken,
    });
    const response = await fetch(
      `${THREADS_API_BASE}/${mediaId}/insights?${params.toString()}`,
    );
    if (!response.ok) {
      throw new Error(
        `Threads insights fetch failed: ${response.status} ${await response.text()}`,
      );
    }
    return response.json();
  }

  /**
   * LinkedIn engagement via socialActions on the post's share URN. The URN
   * (e.g. `urn:li:share:123`) contains colons, so it's percent-encoded into
   * the path. Impressions aren't available here — see normalizeLinkedIn.
   */
  private async fetchLinkedIn(shareUrn: string, accessToken: string): Promise<unknown> {
    const response = await fetch(
      `${LINKEDIN_REST_BASE}/socialActions/${encodeURIComponent(shareUrn)}`,
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'LinkedIn-Version': LINKEDIN_VERSION,
          'X-Restli-Protocol-Version': '2.0.0',
        },
      },
    );
    if (!response.ok) {
      throw new Error(
        `LinkedIn metrics fetch failed: ${response.status} ${await response.text()}`,
      );
    }
    return response.json();
  }
}
