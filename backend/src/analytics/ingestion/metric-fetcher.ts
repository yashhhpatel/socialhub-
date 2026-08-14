import { Injectable } from '@nestjs/common';
import { Platform } from '@prisma/client';

const IG_GRAPH_BASE = 'https://graph.instagram.com';
const X_API_BASE = 'https://api.x.com/2';

// The Instagram media-insight metrics we map into CanonicalMetrics. Kept
// narrow on purpose — requesting a metric the media type doesn't support
// makes the whole call 400, so we ask only for the widely-supported ones.
const IG_METRICS = ['impressions', 'reach', 'likes', 'comments', 'shares'];

/**
 * Pulls one published post's raw insights payload from its platform
 * (Phase 10). Returns the platform's response untouched — turning it into
 * canonical numbers is metric-normalization.ts's job, kept separate so the
 * mapping can be unit-tested without any network.
 *
 * Uses Node's built-in fetch, like the platform adapters. Only Instagram
 * and X are wired for Milestone 10.1; the rest throw until 10.2 adds them,
 * and the ingestion service records that as a per-post failure rather than
 * aborting the whole run.
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
      default:
        throw new Error(`Metric ingestion for ${platform} is not implemented yet.`);
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
}
