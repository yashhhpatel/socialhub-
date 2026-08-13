import { NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import { Platform } from '@prisma/client';

import { PublishingService } from './publishing.service';

describe('PublishingService', () => {
  let service: PublishingService;
  let prisma: {
    contentVariant: { findUnique: jest.Mock };
    socialAccount: { findUnique: jest.Mock };
    publishJob: { create: jest.Mock; update: jest.Mock; findUnique: jest.Mock };
  };
  let instagramAdapter: { publish: jest.Mock };
  let xAdapter: { publish: jest.Mock };

  const readyVariant = {
    id: 'var_1',
    platform: Platform.x,
    status: 'ready',
    renderedMediaUrl: 'https://cdn.test/var_1.png',
    caption: 'Hello world',
    asset: { orgId: 'org_1' },
  };

  const connectedAccount = {
    id: 'sa_1',
    orgId: 'org_1',
    platform: Platform.x,
    status: 'connected',
    externalAccountId: 'x_123',
    accessTokenEnc: 'ENC(token)',
  };

  beforeEach(() => {
    prisma = {
      contentVariant: { findUnique: jest.fn().mockResolvedValue(readyVariant) },
      socialAccount: { findUnique: jest.fn().mockResolvedValue(connectedAccount) },
      publishJob: {
        create: jest.fn().mockResolvedValue({ id: 'job_1', status: 'processing' }),
        update: jest.fn((args) => ({ id: 'job_1', ...args.data })),
        findUnique: jest.fn(),
      },
    };
    instagramAdapter = { publish: jest.fn() };
    xAdapter = { publish: jest.fn().mockResolvedValue({ externalPostId: 'tweet_9' }) };

    service = new PublishingService(
      prisma as never,
      { decrypt: (v: string) => v.replace(/^ENC\(|\)$/g, '') } as never,
      instagramAdapter as never,
      xAdapter as never,
    );
  });

  describe('publishNow — happy path', () => {
    it('publishes through the adapter matching the account platform', async () => {
      await service.publishNow('org_1', 'var_1', 'sa_1');

      expect(xAdapter.publish).toHaveBeenCalledTimes(1);
      expect(instagramAdapter.publish).not.toHaveBeenCalled();
    });

    it('decrypts the stored token — the adapter must never see ciphertext', async () => {
      await service.publishNow('org_1', 'var_1', 'sa_1');

      expect(xAdapter.publish).toHaveBeenCalledWith(
        expect.objectContaining({ accessToken: 'token' }),
      );
    });

    it('records the job BEFORE calling the platform, so a crash leaves a trace', async () => {
      const order: string[] = [];
      prisma.publishJob.create.mockImplementation(async () => {
        order.push('job-created');
        return { id: 'job_1' };
      });
      xAdapter.publish.mockImplementation(async () => {
        order.push('platform-called');
        return { externalPostId: 'tweet_9' };
      });

      await service.publishNow('org_1', 'var_1', 'sa_1');

      expect(order).toEqual(['job-created', 'platform-called']);
    });

    it("stores the platform's post id, the join key analytics needs later", async () => {
      await service.publishNow('org_1', 'var_1', 'sa_1');

      expect(prisma.publishJob.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: 'published',
            externalPostId: 'tweet_9',
          }),
        }),
      );
    });
  });

  describe('publishNow — caption resolution (Milestone 5.3)', () => {
    it('falls back to the variant\'s stored caption when none is supplied', async () => {
      await service.publishNow('org_1', 'var_1', 'sa_1');

      expect(xAdapter.publish).toHaveBeenCalledWith(
        expect.objectContaining({ caption: 'Hello world' }),
      );
    });

    it('prefers the caption supplied with the request over the stored one', async () => {
      await service.publishNow('org_1', 'var_1', 'sa_1', 'Freshly generated caption');

      expect(xAdapter.publish).toHaveBeenCalledWith(
        expect.objectContaining({ caption: 'Freshly generated caption' }),
      );
    });

    it('treats an empty caption as a deliberate choice, not a fallback trigger', async () => {
      // `??` not `||` — clearing the field must post without a caption
      // rather than silently resurrecting the variant's older text.
      await service.publishNow('org_1', 'var_1', 'sa_1', '');

      expect(xAdapter.publish).toHaveBeenCalledWith(
        expect.objectContaining({ caption: '' }),
      );
    });

    it('sends an empty string when neither the request nor the variant has one', async () => {
      prisma.contentVariant.findUnique.mockResolvedValue({
        ...readyVariant,
        caption: null,
      });

      await service.publishNow('org_1', 'var_1', 'sa_1');

      expect(xAdapter.publish).toHaveBeenCalledWith(
        expect.objectContaining({ caption: '' }),
      );
    });

    it('does not write the request caption back onto the variant', async () => {
      // The caption belongs to this attempt. Persisting it is a separate
      // concern with its own endpoint, and this service must not quietly
      // take it on.
      await service.publishNow('org_1', 'var_1', 'sa_1', 'Just for this post');

      expect(
        (prisma.contentVariant as unknown as { update?: jest.Mock }).update,
      ).toBeUndefined();
    });
  });

  describe('publishNow — failure handling', () => {
    it("records the platform's own error text verbatim, not a generic message", async () => {
      xAdapter.publish.mockRejectedValue(new Error('X publish failed: 403 caption too long'));

      await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
        UnprocessableEntityException,
      );

      expect(prisma.publishJob.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: 'failed',
            lastError: 'X publish failed: 403 caption too long',
          }),
        }),
      );
    });

    it('does NOT retry — a blind retry after an ambiguous failure double-posts', async () => {
      xAdapter.publish.mockRejectedValue(new Error('timeout'));

      await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow();

      expect(xAdapter.publish).toHaveBeenCalledTimes(1);
    });
  });

  describe('publishNow — preconditions', () => {
    it('refuses a variant that is not ready', async () => {
      prisma.contentVariant.findUnique.mockResolvedValue({
        ...readyVariant,
        status: 'pending',
      });

      await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
        UnprocessableEntityException,
      );
      expect(xAdapter.publish).not.toHaveBeenCalled();
    });

    it('refuses a variant with no rendered image', async () => {
      prisma.contentVariant.findUnique.mockResolvedValue({
        ...readyVariant,
        renderedMediaUrl: null,
      });

      await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
        UnprocessableEntityException,
      );
    });

    it('refuses a disconnected account', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        ...connectedAccount,
        status: 'revoked',
      });

      await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
        UnprocessableEntityException,
      );
      expect(xAdapter.publish).not.toHaveBeenCalled();
    });

    it('refuses a platform mismatch — an X rendition must not go to Instagram', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        ...connectedAccount,
        platform: Platform.instagram,
      });

      // This one matters: publishing a 16:9 X rendition to Instagram
      // would "succeed" and merely look wrong, which is far harder to
      // notice than an outright failure.
      await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
        UnprocessableEntityException,
      );
      expect(instagramAdapter.publish).not.toHaveBeenCalled();
    });

    it("404s a variant belonging to another org, never 403", async () => {
      prisma.contentVariant.findUnique.mockResolvedValue({
        ...readyVariant,
        asset: { orgId: 'other_org' },
      });

      await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
        NotFoundException,
      );
    });

    it("404s an account belonging to another org", async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        ...connectedAccount,
        orgId: 'other_org',
      });

      await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('findJobScoped', () => {
    it('returns a job owned by the caller org', async () => {
      prisma.publishJob.findUnique.mockResolvedValue({
        id: 'job_1',
        socialAccount: { orgId: 'org_1' },
      });

      expect((await service.findJobScoped('job_1', 'org_1')).id).toBe('job_1');
    });

    it("404s another org's job rather than revealing it exists", async () => {
      prisma.publishJob.findUnique.mockResolvedValue({
        id: 'job_1',
        socialAccount: { orgId: 'other_org' },
      });

      await expect(service.findJobScoped('job_1', 'org_1')).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
