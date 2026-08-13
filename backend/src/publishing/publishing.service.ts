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

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { PrismaService } from '../prisma/prisma.service';
import { PlatformAdapter } from '../social-accounts/adapters/adapter.interface';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';

/**
 * Synchronous publish for the MVP platforms (Milestone 4.2).
 *
 * SYNCHRONOUS BY DESIGN, FOR NOW: the blueprint defers the queue to Phase
 * 7. A job therefore goes processing -> published|failed inside the
 * request. The PublishJob row is still written BEFORE the platform call
 * and updated after, rather than only on success — otherwise a crash
 * mid-publish would leave no record that anything was attempted, and the
 * user would have no way to tell "never sent" from "sent and we lost the
 * receipt". That distinction is exactly what makes double-posting
 * avoidable.
 *
 * NO AUTOMATIC RETRY. A failed publish is recorded with the platform's
 * own error text and left for a human to decide about. Retrying blindly
 * after an ambiguous failure — a timeout that may have landed — is how
 * you post twice.
 */
@Injectable()
export class PublishingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenEncryption: TokenEncryptionService,
    instagramAdapter: InstagramAdapter,
    xAdapter: XAdapter,
  ) {
    this.adapters = {
      [Platform.instagram]: instagramAdapter,
      [Platform.x]: xAdapter,
    };
  }

  private readonly adapters: Partial<Record<Platform, PlatformAdapter>>;

  /**
   * @param caption Overrides the variant's stored caption for this attempt
   *   (Milestone 5.3). The publish modal's generated/edited caption belongs
   *   to the attempt, not to the variant — see PublishNowDto.
   */
  async publishNow(
    orgId: string,
    variantId: string,
    socialAccountId: string,
    caption?: string,
  ): Promise<PublishJob> {
    const { variant, account } = await this.loadAndValidate(
      orgId,
      variantId,
      socialAccountId,
    );

    const adapter = this.adapters[account.platform];
    if (!adapter) {
      throw new UnprocessableEntityException(
        `Publishing to ${account.platform} is not supported yet.`,
      );
    }

    // Written before the platform call — see the class note on why a
    // record must exist even if this process dies mid-publish.
    const job = await this.prisma.publishJob.create({
      data: {
        variantId,
        socialAccountId,
        status: PublishJobStatus.processing,
        attemptCount: 1,
      },
    });

    try {
      const result = await adapter.publish({
        imageUrl: variant.renderedMediaUrl as string,
        // Request caption wins, then the variant's stored one, then empty.
        // `??` and not `||`: an empty string is a deliberate choice to post
        // without a caption, and must not silently fall back to the
        // variant's older text.
        caption: caption ?? variant.caption ?? '',
        externalAccountId: account.externalAccountId,
        accessToken: this.tokenEncryption.decrypt(account.accessTokenEnc),
      });

      return await this.prisma.publishJob.update({
        where: { id: job.id },
        data: {
          status: PublishJobStatus.published,
          externalPostId: result.externalPostId,
          lastError: null,
        },
      });
    } catch (error) {
      // The platform's own message is preserved verbatim: "caption too
      // long" or "media not reachable" is the only thing that tells the
      // user what to actually change. A generic "publish failed" would
      // strip exactly the information that makes the failure actionable.
      const message = error instanceof Error ? error.message : 'Publish failed.';

      await this.prisma.publishJob.update({
        where: { id: job.id },
        data: { status: PublishJobStatus.failed, lastError: message },
      });

      throw new UnprocessableEntityException(message);
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
   * same platform.
   *
   * The platform match is the one worth being strict about — publishing
   * a 16:9 X rendition to Instagram would "succeed" and simply look
   * wrong, which is far harder to notice than an outright failure.
   */
  private async loadAndValidate(orgId: string, variantId: string, socialAccountId: string) {
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
