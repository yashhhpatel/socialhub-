import { Injectable, Logger } from '@nestjs/common';
import { Platform, PublishJobStatus, SocialAccountStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

/** Minimal shape of a Meta Graph API webhook delivery. */
interface MetaWebhookChange {
  field?: string;
  value?: Record<string, unknown>;
}
interface MetaWebhookEntry {
  id?: string;
  time?: number;
  changes?: MetaWebhookChange[];
}
export interface MetaWebhookPayload {
  object?: string;
  entry?: MetaWebhookEntry[];
}

const POST_REMOVAL_FIELDS = new Set(['feed', 'mentions', 'media']);
const POST_REMOVAL_VERBS = new Set(['remove', 'delete', 'hide', 'unpublish']);

/**
 * Handles verified inbound platform webhook events (Phase 20).
 *
 * Scope: Meta platforms (Instagram, Facebook, Threads) share the Graph API
 * webhook protocol. Two event classes are mapped onto our data, both applied
 * with conditional `updateMany`s so re-delivery of the same event is a no-op
 * (idempotent) — no dedupe table needed:
 *   1. A published post removed/deleted on the platform  → the PublishJob that
 *      created it is marked `failed` (content status reflects reality).
 *   2. A permission/app removal for an account            → the SocialAccount is
 *      marked `revoked` so it's surfaced for reconnection (ties into the token
 *      refresh/reconnect flow).
 * Anything else is a safe, logged no-op.
 */
@Injectable()
export class WebhooksService {
  private readonly logger = new Logger(WebhooksService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Dispatch a verified Meta webhook payload. Returns how many changes it acted on. */
  async handleMetaEvent(
    platform: Platform,
    payload: MetaWebhookPayload,
  ): Promise<{ handled: number }> {
    let handled = 0;
    for (const entry of payload.entry ?? []) {
      for (const change of entry.changes ?? []) {
        if (await this.handleChange(platform, entry, change)) handled += 1;
      }
    }
    return { handled };
  }

  private async handleChange(
    platform: Platform,
    entry: MetaWebhookEntry,
    change: MetaWebhookChange,
  ): Promise<boolean> {
    const field = change.field ?? '';
    const value = change.value ?? {};
    const verb = asString(value.verb) ?? asString(value.action);

    // 1) Post removed/deleted on the platform → fail its PublishJob.
    if (POST_REMOVAL_FIELDS.has(field) && verb && POST_REMOVAL_VERBS.has(verb)) {
      const postId =
        asString(value.post_id) ?? asString(value.media_id) ?? asString(value.id);
      if (postId) return this.markPostRemoved(platform, postId);
    }

    // 2) Permission/app removal → mark the account for reconnection.
    if (field === 'permissions') {
      const revoked =
        verb === 'revoke' ||
        asString(value.status) === 'removed' ||
        asString(value.status) === 'unsubscribed';
      const externalUserId = entry.id;
      if (revoked && externalUserId) {
        return this.markAccountRevoked(platform, externalUserId);
      }
    }

    this.logger.debug(`Unmapped ${platform} webhook change (field=${field})`);
    return false;
  }

  /** Idempotent: only a still-`published` job for this post id transitions. */
  private async markPostRemoved(
    platform: Platform,
    externalPostId: string,
  ): Promise<boolean> {
    const result = await this.prisma.publishJob.updateMany({
      where: {
        externalPostId,
        status: PublishJobStatus.published,
        socialAccount: { platform },
      },
      data: {
        status: PublishJobStatus.failed,
        lastError: `Post was removed on ${platform}.`,
      },
    });
    if (result.count > 0) {
      this.logger.log(`Marked ${result.count} job(s) failed: post ${externalPostId} removed on ${platform}.`);
    }
    return result.count > 0;
  }

  /** Idempotent: only a not-already-revoked account transitions. */
  private async markAccountRevoked(
    platform: Platform,
    externalUserId: string,
  ): Promise<boolean> {
    const result = await this.prisma.socialAccount.updateMany({
      where: {
        platform,
        externalUserId,
        status: { not: SocialAccountStatus.revoked },
      },
      data: { status: SocialAccountStatus.revoked },
    });
    if (result.count > 0) {
      this.logger.log(`Marked ${result.count} ${platform} account(s) revoked (webhook permission removal).`);
    }
    return result.count > 0;
  }
}

function asString(v: unknown): string | undefined {
  return typeof v === 'string' && v.length > 0 ? v : undefined;
}
