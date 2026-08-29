import { InjectQueue } from '@nestjs/bullmq';
import {
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  ApprovalStatus,
  Platform,
  PublishJob,
  PublishJobStatus,
  SocialAccount,
  SocialAccountStatus,
  VariantStatus,
} from '@prisma/client';
import { Queue } from 'bullmq';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { PrismaService } from '../prisma/prisma.service';
import { PlatformAdapter } from '../social-accounts/adapters/adapter.interface';
import { FacebookAdapter } from '../social-accounts/adapters/facebook.adapter';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { LinkedInAdapter } from '../social-accounts/adapters/linkedin.adapter';
import { ThreadsAdapter } from '../social-accounts/adapters/threads.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import {
  SocialTokenService,
  TokenReconnectRequiredError,
} from '../social-accounts/social-token.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  PUBLISH_JOB_OPTIONS,
  PUBLISH_QUEUES,
  PublishJobData,
} from './publish-queue.constants';

/**
 * Queue-backed publish (Milestone 7.2 — was synchronous in 4.2).
 *
 * publishNow now VALIDATES synchronously (so a bad request still 404s/422s
 * immediately) and then ENQUEUES onto the target platform's queue, returning
 * a `queued` job. A per-platform worker (see processors/) later runs
 * executePublish, which is the actual platform call plus retry bookkeeping.
 * The API contract is unchanged — POST /publish/now was already async-shaped
 * (202 + a job to poll) since 4.3, precisely so this move needed no change
 * on the frontend.
 *
 * The PublishJob row is still the source of truth for what happened:
 * queued -> processing -> published | failed. attemptCount and lastError
 * track the retry history the queue drives.
 */
@Injectable()
export class PublishingService {
  private readonly adapters: Partial<Record<Platform, PlatformAdapter>>;
  private readonly queues: Partial<Record<Platform, Queue<PublishJobData>>>;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenEncryption: TokenEncryptionService,
    instagramAdapter: InstagramAdapter,
    xAdapter: XAdapter,
    facebookAdapter: FacebookAdapter,
    threadsAdapter: ThreadsAdapter,
    linkedinAdapter: LinkedInAdapter,
    @InjectQueue(PUBLISH_QUEUES[Platform.instagram])
    instagramQueue: Queue<PublishJobData>,
    @InjectQueue(PUBLISH_QUEUES[Platform.x])
    xQueue: Queue<PublishJobData>,
    @InjectQueue(PUBLISH_QUEUES[Platform.facebook])
    facebookQueue: Queue<PublishJobData>,
    @InjectQueue(PUBLISH_QUEUES[Platform.threads])
    threadsQueue: Queue<PublishJobData>,
    @InjectQueue(PUBLISH_QUEUES[Platform.linkedin])
    linkedinQueue: Queue<PublishJobData>,
    private readonly notifications: NotificationsService,
    private readonly socialTokens: SocialTokenService,
  ) {
    this.adapters = {
      [Platform.instagram]: instagramAdapter,
      [Platform.x]: xAdapter,
      [Platform.facebook]: facebookAdapter,
      [Platform.threads]: threadsAdapter,
      [Platform.linkedin]: linkedinAdapter,
    };
    this.queues = {
      [Platform.instagram]: instagramQueue,
      [Platform.x]: xQueue,
      [Platform.facebook]: facebookQueue,
      [Platform.threads]: threadsQueue,
      [Platform.linkedin]: linkedinQueue,
    };
  }

  /**
   * @param caption Overrides the variant's stored caption for this attempt
   *   (Milestone 5.3). Carried in the job's data so the worker uses it.
   */
  async publishNow(
    orgId: string,
    variantId: string,
    socialAccountId: string,
    caption?: string,
  ): Promise<PublishJob> {
    const { account } = await this.loadAndValidate(
      orgId,
      variantId,
      socialAccountId,
    );

    const queue = this.queues[account.platform];
    if (!queue) {
      throw new UnprocessableEntityException(
        `Publishing to ${account.platform} is not supported yet.`,
      );
    }

    // Recorded as `queued` before enqueuing, so there is a row to move to
    // processing/failed no matter what the worker does — the same
    // "a record must exist" guarantee 4.2 had, now across a process boundary.
    const job = await this.prisma.publishJob.create({
      data: {
        variantId,
        socialAccountId,
        status: PublishJobStatus.queued,
        attemptCount: 0,
      },
    });

    await queue.add(
      'publish',
      { publishJobId: job.id, caption },
      PUBLISH_JOB_OPTIONS,
    );

    return job;
  }

  // ---- Carousel posts (media-library multi-image) ------------------------

  /**
   * Publishes an ordered set of media-library images as one native carousel
   * (Phase: carousel posts). Validates synchronously, persists the carousel +
   * a `queued` PublishJob, then enqueues onto the platform's queue — the same
   * shape as publishNow, so the worker/retry/status machinery is shared.
   */
  async publishCarouselNow(
    orgId: string,
    createdById: string,
    socialAccountId: string,
    mediaUrls: string[],
    caption?: string,
  ): Promise<PublishJob> {
    const { queue } = await this.loadAndValidateCarousel(
      orgId,
      socialAccountId,
      mediaUrls,
    );

    const carousel = await this.prisma.carouselPost.create({
      data: { orgId, createdById, mediaUrls, caption: caption ?? null },
    });

    const job = await this.prisma.publishJob.create({
      data: {
        carouselPostId: carousel.id,
        socialAccountId,
        status: PublishJobStatus.queued,
        attemptCount: 0,
      },
    });

    await queue.add(
      'publish',
      { publishJobId: job.id, caption },
      PUBLISH_JOB_OPTIONS,
    );

    return job;
  }

  /** Schedules a carousel for a future time — the carousel twin of schedule(). */
  async scheduleCarousel(
    orgId: string,
    createdById: string,
    socialAccountId: string,
    mediaUrls: string[],
    scheduledAt: Date,
    caption?: string,
  ): Promise<PublishJob> {
    if (scheduledAt.getTime() <= Date.now()) {
      throw new UnprocessableEntityException(
        'Scheduled time must be in the future. To publish now, omit scheduledAt.',
      );
    }

    await this.loadAndValidateCarousel(orgId, socialAccountId, mediaUrls);

    const carousel = await this.prisma.carouselPost.create({
      data: { orgId, createdById, mediaUrls, caption: caption ?? null },
    });

    return this.prisma.publishJob.create({
      data: {
        carouselPostId: carousel.id,
        socialAccountId,
        scheduledAt,
        caption,
        status: PublishJobStatus.scheduled,
        attemptCount: 0,
      },
    });
  }

  /**
   * Preconditions for a carousel: the account is the org's and connected, the
   * platform supports carousels, and the item count is within 2..max. Runs
   * synchronously so a bad request is rejected before anything is persisted.
   */
  private async loadAndValidateCarousel(
    orgId: string,
    socialAccountId: string,
    mediaUrls: string[],
  ): Promise<{ account: SocialAccount; queue: Queue<PublishJobData> }> {
    const account = await this.prisma.socialAccount.findUnique({
      where: { id: socialAccountId },
    });
    if (!account || account.orgId !== orgId) {
      throw new NotFoundException('Social account not found.');
    }
    if (account.status !== SocialAccountStatus.connected) {
      throw new UnprocessableEntityException(
        `That ${account.platform} account is ${account.status}. Reconnect it before publishing.`,
      );
    }

    const adapter = this.adapters[account.platform];
    const queue = this.queues[account.platform];
    const maxItems = adapter?.capabilities().maxCarouselItems;
    if (!adapter || !queue || !maxItems) {
      throw new UnprocessableEntityException(
        `Carousel posts are not supported for ${account.platform}.`,
      );
    }

    if (mediaUrls.length < 2) {
      throw new UnprocessableEntityException('A carousel needs at least 2 images.');
    }
    if (mediaUrls.length > maxItems) {
      throw new UnprocessableEntityException(
        `${account.platform} carousels accept at most ${maxItems} images.`,
      );
    }

    return { account, queue };
  }

  /**
   * The carousel twin of executePublish: identical processing/attempt
   * bookkeeping, token refresh, retry semantics and notifications, but it
   * publishes an ordered set of media URLs via adapter.publishCarousel and
   * notifies the carousel's author directly (there is no content asset).
   */
  private async executeCarouselPublish(
    job: PublishJob,
    data: PublishJobData,
    ctx: { attemptsMade: number; maxAttempts: number },
  ): Promise<void> {
    const carousel = job.carouselPostId
      ? await this.prisma.carouselPost.findUnique({
          where: { id: job.carouselPostId },
        })
      : null;
    const account = await this.prisma.socialAccount.findUnique({
      where: { id: job.socialAccountId },
    });
    const adapter = account ? this.adapters[account.platform] : undefined;

    if (!carousel || carousel.mediaUrls.length < 2 || !account || !adapter) {
      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          status: PublishJobStatus.failed,
          lastError:
            'The carousel or account this job targeted no longer exists.',
        },
      });
      return;
    }

    await this.prisma.publishJob.update({
      where: { id: job.id },
      data: {
        status: PublishJobStatus.processing,
        attemptCount: ctx.attemptsMade + 1,
      },
    });

    let accessToken: string;
    try {
      accessToken = await this.socialTokens.ensureFreshAccessToken(account);
    } catch (err) {
      if (err instanceof TokenReconnectRequiredError) {
        await this.prisma.publishJob.update({
          where: { id: job.id },
          data: {
            status: PublishJobStatus.failed,
            lastError: `${account.platform} needs to be reconnected (token ${err.status}). Reconnect the account in Settings and republish.`,
          },
        });
        await this.notifyUser(carousel.createdById, {
          type: 'publish_failed',
          title: 'Reconnect required',
          body: `Your ${account.platform} account needs to be reconnected before posts can publish.`,
        });
        return;
      }
      throw err;
    }

    try {
      const result = await adapter.publishCarousel({
        mediaUrls: carousel.mediaUrls,
        caption: data.caption ?? carousel.caption ?? '',
        externalAccountId: account.externalAccountId,
        accessToken,
      });

      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          status: PublishJobStatus.published,
          externalPostId: result.externalPostId,
          lastError: null,
        },
      });

      await this.notifyUser(carousel.createdById, {
        type: 'publish_succeeded',
        title: 'Post published',
        body: `Your carousel was published to ${account.platform}.`,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Publish failed.';
      const isFinalAttempt = ctx.attemptsMade + 1 >= ctx.maxAttempts;

      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          status: isFinalAttempt
            ? PublishJobStatus.failed
            : PublishJobStatus.processing,
          lastError: message,
        },
      });

      if (isFinalAttempt) {
        await this.notifyUser(carousel.createdById, {
          type: 'publish_failed',
          title: 'Post failed',
          body: `Your carousel to ${account.platform} failed: ${message}`,
        });
      }
      throw error;
    }
  }

  /**
   * The actual platform call, run by a per-platform worker (processors/).
   *
   * Throws on failure so BullMQ applies the backoff/retry policy. The DB row
   * is updated on every attempt; only once retries are exhausted is it marked
   * `failed`, so a job mid-retry reads as `processing`, not a premature
   * failure. Never retries on its own — the retry is the queue's, bounded by
   * PUBLISH_JOB_OPTIONS.attempts.
   */
  async executePublish(
    data: PublishJobData,
    ctx: { attemptsMade: number; maxAttempts: number },
  ): Promise<void> {
    const job = await this.prisma.publishJob.findUnique({
      where: { id: data.publishJobId },
    });
    // The job was cancelled/deleted between enqueue and now. Nothing to do,
    // and nothing to retry — returning (not throwing) lets BullMQ complete it.
    if (!job) {
      return;
    }

    // A carousel job (media-library multi-image) takes its own path.
    if (job.carouselPostId) {
      await this.executeCarouselPublish(job, data, ctx);
      return;
    }

    if (!job.variantId) {
      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          status: PublishJobStatus.failed,
          lastError: 'This job targets neither a variant nor a carousel.',
        },
      });
      return;
    }

    const variant = await this.prisma.contentVariant.findUnique({
      where: { id: job.variantId },
    });
    const account = await this.prisma.socialAccount.findUnique({
      where: { id: job.socialAccountId },
    });
    const adapter = account ? this.adapters[account.platform] : undefined;

    if (!variant || !variant.renderedMediaUrl || !account || !adapter) {
      // A dependency disappeared after enqueue — terminal, not retryable.
      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          status: PublishJobStatus.failed,
          lastError:
            'The variant or account this job targeted no longer exists.',
        },
      });
      return;
    }

    await this.prisma.publishJob.update({
      where: { id: job.id },
      data: {
        status: PublishJobStatus.processing,
        attemptCount: ctx.attemptsMade + 1,
      },
    });

    // Ensure the token is fresh (refresh proactively if near expiry). If the
    // account is expired/revoked and can't be refreshed, this is a PERMANENT
    // condition — fail the job terminally now and notify the owner to
    // reconnect, rather than throwing (which would burn retries and let the
    // post silently fail every attempt).
    let accessToken: string;
    try {
      accessToken = await this.socialTokens.ensureFreshAccessToken(account);
    } catch (err) {
      if (err instanceof TokenReconnectRequiredError) {
        await this.prisma.publishJob.update({
          where: { id: job.id },
          data: {
            status: PublishJobStatus.failed,
            lastError: `${account.platform} needs to be reconnected (token ${err.status}). Reconnect the account in Settings and republish.`,
          },
        });
        await this.notifyOwner(variant.assetId, account.platform, {
          type: 'publish_failed',
          title: 'Reconnect required',
          body: `Your ${account.platform} account needs to be reconnected before posts can publish.`,
        });
        return; // terminal — do not throw, do not retry
      }
      throw err;
    }

    try {
      const result = await adapter.publish({
        imageUrl: variant.renderedMediaUrl,
        // Request caption wins, then the variant's stored one, then empty.
        // `??` not `||`: an empty caption is a deliberate choice to post
        // without one and must not resurrect the variant's older text.
        caption: data.caption ?? variant.caption ?? '',
        externalAccountId: account.externalAccountId,
        accessToken,
      });

      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          status: PublishJobStatus.published,
          externalPostId: result.externalPostId,
          lastError: null,
        },
      });

      // Notify the design's author that their post went out (Phase 19).
      await this.notifyOwner(variant.assetId, account.platform, {
        type: 'publish_succeeded',
        title: 'Post published',
        body: `Your post was published to ${account.platform}.`,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Publish failed.';
      const isFinalAttempt = ctx.attemptsMade + 1 >= ctx.maxAttempts;

      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          // Stay `processing` between retries; only the exhausted attempt is
          // `failed`, so status never lies about whether more will be tried.
          status: isFinalAttempt
            ? PublishJobStatus.failed
            : PublishJobStatus.processing,
          lastError: message,
        },
      });

      // Only notify once retries are exhausted, so a transient blip that later
      // succeeds doesn't alarm the user (Phase 19).
      if (isFinalAttempt) {
        await this.notifyOwner(variant.assetId, account.platform, {
          type: 'publish_failed',
          title: 'Post failed',
          body: `Your post to ${account.platform} failed: ${message}`,
        });
      }

      // Rethrow so BullMQ schedules the next attempt (or moves the job to its
      // failed set once attempts are exhausted).
      throw error;
    }
  }

  /// Best-effort notification to a design's author about a publish outcome.
  private async notifyOwner(
    assetId: string,
    platform: Platform,
    n: { type: 'publish_succeeded' | 'publish_failed'; title: string; body: string },
  ): Promise<void> {
    const asset = await this.prisma.contentAsset.findUnique({
      where: { id: assetId },
      select: { createdById: true },
    });
    if (!asset) return;
    await this.notifyUser(asset.createdById, n);
  }

  /// Best-effort publish-outcome notification to a specific user (used by the
  /// carousel path, whose author is known directly rather than via an asset).
  private async notifyUser(
    userId: string,
    n: { type: 'publish_succeeded' | 'publish_failed'; title: string; body: string },
  ): Promise<void> {
    await this.notifications.notifySafe({
      userId,
      type: n.type,
      title: n.title,
      body: n.body,
      linkPath: '/calendar',
    });
  }

  /**
   * Schedules a publish for a future time (Milestone 7.3).
   *
   * Validates exactly as publishNow does, then records a `scheduled`
   * PublishJob with its scheduledAt and caption — but does NOT enqueue it.
   * The row IS the durable schedule: it survives a Redis restart, unlike a
   * BullMQ delayed job would, which matters for a post set days out. The
   * cron (schedule.cron.ts) enqueues it once it comes due.
   */
  async schedule(
    orgId: string,
    variantId: string,
    socialAccountId: string,
    scheduledAt: Date,
    caption?: string,
  ): Promise<PublishJob> {
    if (scheduledAt.getTime() <= Date.now()) {
      throw new UnprocessableEntityException(
        'Scheduled time must be in the future. To publish now, use /publish/now.',
      );
    }

    // Same preconditions as an immediate publish, checked now so an invalid
    // schedule is rejected at request time rather than silently failing when
    // it later comes due.
    await this.loadAndValidate(orgId, variantId, socialAccountId);

    return this.prisma.publishJob.create({
      data: {
        variantId,
        socialAccountId,
        scheduledAt,
        caption,
        status: PublishJobStatus.scheduled,
        attemptCount: 0,
      },
    });
  }

  /**
   * Enqueues every scheduled job that has come due (Milestone 7.3), called
   * by the cron. Returns how many it dispatched.
   *
   * Each job is CLAIMED atomically — an updateMany from `scheduled` to
   * `queued` gated on the row still being `scheduled` — before it is
   * enqueued. Two overlapping cron ticks (or two instances) therefore can't
   * both enqueue the same job: only the tick whose update matched a
   * still-`scheduled` row proceeds. Enqueue happens after the claim, so a
   * job is `queued` in the DB exactly when it enters the queue.
   */
  async dispatchDueScheduledJobs(now: Date = new Date()): Promise<number> {
    const due = await this.prisma.publishJob.findMany({
      where: { status: PublishJobStatus.scheduled, scheduledAt: { lte: now } },
      include: { socialAccount: { select: { platform: true } } },
    });

    let dispatched = 0;
    for (const job of due) {
      // Claim it. If another tick already did, count is 0 and we skip.
      const claimed = await this.prisma.publishJob.updateMany({
        where: { id: job.id, status: PublishJobStatus.scheduled },
        data: { status: PublishJobStatus.queued },
      });
      if (claimed.count !== 1) {
        continue;
      }

      const queue = this.queues[job.socialAccount.platform];
      if (!queue) {
        // A platform whose queue was removed — mark failed rather than leave
        // it stuck as queued-but-never-processed.
        await this.prisma.publishJob.update({
          where: { id: job.id },
          data: {
            status: PublishJobStatus.failed,
            lastError: `No queue for platform ${job.socialAccount.platform}.`,
          },
        });
        continue;
      }

      await queue.add(
        'publish',
        { publishJobId: job.id, caption: job.caption ?? undefined },
        PUBLISH_JOB_OPTIONS,
      );
      dispatched += 1;
    }

    return dispatched;
  }

  /**
   * Re-enqueue a job for another publish attempt (admin action, Phase 21.7).
   * Cross-tenant by design — the caller is a platform admin, not an org member.
   * A published job is never re-run (that would double-post).
   */
  async requeueJob(jobId: string): Promise<void> {
    const job = await this.prisma.publishJob.findUnique({
      where: { id: jobId },
      include: { socialAccount: { select: { platform: true } } },
    });
    if (!job) throw new NotFoundException('Publish job not found.');
    if (job.status === PublishJobStatus.published) {
      throw new UnprocessableEntityException(
        'This job already published; re-running would double-post.',
      );
    }

    const queue = this.queues[job.socialAccount.platform];
    if (!queue) {
      throw new UnprocessableEntityException(
        `No queue for platform ${job.socialAccount.platform}.`,
      );
    }

    await this.prisma.publishJob.update({
      where: { id: jobId },
      data: { status: PublishJobStatus.queued, lastError: null },
    });
    await queue.add(
      'publish',
      { publishJobId: job.id, caption: job.caption ?? undefined },
      PUBLISH_JOB_OPTIONS,
    );
  }

  /**
   * Cancel a job (admin action, Phase 21.7). Cross-tenant. A published job
   * can't be cancelled (it already went out).
   */
  async cancelJob(jobId: string): Promise<void> {
    const job = await this.prisma.publishJob.findUnique({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Publish job not found.');
    if (job.status === PublishJobStatus.published) {
      throw new UnprocessableEntityException(
        'A published job cannot be cancelled.',
      );
    }
    await this.prisma.publishJob.update({
      where: { id: jobId },
      data: { status: PublishJobStatus.cancelled },
    });
  }

  async findJobScoped(jobId: string, orgId: string): Promise<PublishJob> {
    const job = await this.prisma.publishJob.findUnique({
      where: { id: jobId },
      include: { socialAccount: { select: { orgId: true } } },
    });

    // Same rule as content assets: 404 rather than 403 for another org's
    // job, so a caller can't probe for the existence of ids they don't own.
    if (!job || job.socialAccount.orgId !== orgId) {
      throw new NotFoundException('Publish job not found.');
    }

    return job;
  }

  /**
   * The org's publish jobs, newest first, for the scheduler/calendar view
   * (Milestone 7.4). Org-scoped through the socialAccount relation — the
   * same tenant boundary every other query enforces. Optional status filter
   * (e.g. only `scheduled`).
   */
  async listJobs(
    orgId: string,
    status?: PublishJobStatus,
  ): Promise<
    Array<
      PublishJob & { socialAccount: { platform: Platform; externalAccountId: string } }
    >
  > {
    return this.prisma.publishJob.findMany({
      where: {
        socialAccount: { orgId },
        ...(status ? { status } : {}),
      },
      include: {
        socialAccount: { select: { platform: true, externalAccountId: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  /**
   * Cancels a still-scheduled job (Milestone 7.4).
   *
   * Only a `scheduled` job can be cancelled — once it has been enqueued or
   * published there is nothing safe to cancel (a `processing` job may already
   * be mid-post, and cancelling a `published` one cannot unpublish it). The
   * status guard on updateMany makes the check-and-set atomic against the
   * cron claiming the same job at the same instant.
   */
  async cancelScheduled(jobId: string, orgId: string): Promise<PublishJob> {
    // Scopes to the org (404s another org's job) before touching anything.
    const job = await this.findJobScoped(jobId, orgId);

    if (job.status !== PublishJobStatus.scheduled) {
      throw new UnprocessableEntityException(
        `This job is ${job.status} and can no longer be cancelled. Only a scheduled post can be.`,
      );
    }

    const cancelled = await this.prisma.publishJob.updateMany({
      where: { id: jobId, status: PublishJobStatus.scheduled },
      data: { status: PublishJobStatus.cancelled },
    });

    // The cron claimed it in the gap between the read and here.
    if (cancelled.count !== 1) {
      throw new UnprocessableEntityException(
        'This job just started publishing and can no longer be cancelled.',
      );
    }

    return this.findJobScoped(jobId, orgId);
  }

  /**
   * Enforces the preconditions from the REST design doc: variant must be
   * `ready`, account must be `connected`, and the two must be for the
   * same platform. Runs synchronously in publishNow so an invalid request
   * is rejected before anything is queued.
   */
  private async loadAndValidate(
    orgId: string,
    variantId: string,
    socialAccountId: string,
  ) {
    const variant = await this.prisma.contentVariant.findUnique({
      where: { id: variantId },
      include: {
        asset: {
          select: {
            orgId: true,
            // Approval gate (Milestone 13.2): both the asset's status and
            // whether its org even requires approval are needed to decide.
            approvalStatus: true,
            organization: { select: { requiresApproval: true } },
          },
        },
      },
    });

    if (!variant || variant.asset.orgId !== orgId) {
      throw new NotFoundException('Content variant not found.');
    }

    // In an org that requires approval, an unapproved design cannot be
    // published — the core guarantee of the approval workflow. Orgs with
    // requiresApproval=false (the default) are unaffected.
    if (
      variant.asset.organization.requiresApproval &&
      variant.asset.approvalStatus !== ApprovalStatus.approved
    ) {
      throw new UnprocessableEntityException(
        'This design must be approved before it can be published.',
      );
    }

    const account = await this.prisma.socialAccount.findUnique({
      where: { id: socialAccountId },
    });

    if (!account || account.orgId !== orgId) {
      throw new NotFoundException('Social account not found.');
    }

    if (variant.status !== VariantStatus.ready) {
      throw new UnprocessableEntityException(
        'This variant is not ready to publish. Generate platform variants first.',
      );
    }

    if (!variant.renderedMediaUrl) {
      throw new UnprocessableEntityException(
        'This variant has no rendered image to publish.',
      );
    }

    if (account.status !== SocialAccountStatus.connected) {
      throw new UnprocessableEntityException(
        `That ${account.platform} account is ${account.status}. Reconnect it before publishing.`,
      );
    }

    if (account.platform !== variant.platform) {
      throw new UnprocessableEntityException(
        `This variant was rendered for ${variant.platform}, but the selected account is ${account.platform}.`,
      );
    }

    return { variant, account };
  }
}
