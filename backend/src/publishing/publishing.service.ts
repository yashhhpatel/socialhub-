import { InjectQueue } from '@nestjs/bullmq';
import {
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  Platform,
  PublishJob,
  PublishJobStatus,
  SocialAccountStatus,
  VariantStatus,
} from '@prisma/client';
import { Queue } from 'bullmq';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { PrismaService } from '../prisma/prisma.service';
import { PlatformAdapter } from '../social-accounts/adapters/adapter.interface';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
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
    @InjectQueue(PUBLISH_QUEUES[Platform.instagram])
    instagramQueue: Queue<PublishJobData>,
    @InjectQueue(PUBLISH_QUEUES[Platform.x])
    xQueue: Queue<PublishJobData>,
  ) {
    this.adapters = {
      [Platform.instagram]: instagramAdapter,
      [Platform.x]: xAdapter,
    };
    this.queues = {
      [Platform.instagram]: instagramQueue,
      [Platform.x]: xQueue,
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

    try {
      const result = await adapter.publish({
        imageUrl: variant.renderedMediaUrl,
        // Request caption wins, then the variant's stored one, then empty.
        // `??` not `||`: an empty caption is a deliberate choice to post
        // without one and must not resurrect the variant's older text.
        caption: data.caption ?? variant.caption ?? '',
        externalAccountId: account.externalAccountId,
        accessToken: this.tokenEncryption.decrypt(account.accessTokenEnc),
      });

      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          status: PublishJobStatus.published,
          externalPostId: result.externalPostId,
          lastError: null,
        },
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

      // Rethrow so BullMQ schedules the next attempt (or moves the job to its
      // failed set once attempts are exhausted).
      throw error;
    }
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
      include: { asset: { select: { orgId: true } } },
    });

    if (!variant || variant.asset.orgId !== orgId) {
      throw new NotFoundException('Content variant not found.');
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
