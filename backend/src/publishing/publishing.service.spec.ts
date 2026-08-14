import { NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import { Platform } from '@prisma/client';

import { PUBLISH_JOB_OPTIONS, PUBLISH_QUEUES } from './publish-queue.constants';
import { PublishingService } from './publishing.service';

describe('PublishingService', () => {
  let service: PublishingService;
  let prisma: {
    contentVariant: { findUnique: jest.Mock };
    socialAccount: { findUnique: jest.Mock };
    publishJob: {
      create: jest.Mock;
      update: jest.Mock;
      findUnique: jest.Mock;
      findMany: jest.Mock;
      updateMany: jest.Mock;
    };
  };
  let instagramAdapter: { publish: jest.Mock };
  let xAdapter: { publish: jest.Mock };
  let facebookAdapter: { publish: jest.Mock };
  let threadsAdapter: { publish: jest.Mock };
  let linkedinAdapter: { publish: jest.Mock };
  let igQueue: { add: jest.Mock };
  let xQueue: { add: jest.Mock };
  let fbQueue: { add: jest.Mock };
  let thQueue: { add: jest.Mock };
  let liQueue: { add: jest.Mock };

  const readyVariant = {
    id: 'var_1',
    platform: Platform.x,
    status: 'ready',
    renderedMediaUrl: 'https://cdn.test/var_1.png',
    caption: 'Hello world',
    // approvalStatus + org.requiresApproval drive the approval gate (13.2);
    // the default org here does NOT require approval, so publishing is
    // unaffected unless a test opts in.
    asset: {
      orgId: 'org_1',
      approvalStatus: 'draft',
      organization: { requiresApproval: false },
    },
  };

  const connectedAccount = {
    id: 'sa_1',
    orgId: 'org_1',
    platform: Platform.x,
    status: 'connected',
    externalAccountId: 'x_123',
    accessTokenEnc: 'ENC(token)',
  };

  const jobRow = {
    id: 'job_1',
    variantId: 'var_1',
    socialAccountId: 'sa_1',
    status: 'queued',
    attemptCount: 0,
  };

  beforeEach(() => {
    prisma = {
      contentVariant: { findUnique: jest.fn().mockResolvedValue(readyVariant) },
      socialAccount: { findUnique: jest.fn().mockResolvedValue(connectedAccount) },
      publishJob: {
        create: jest.fn().mockResolvedValue(jobRow),
        update: jest.fn((args) => ({ ...jobRow, ...args.data })),
        findUnique: jest.fn().mockResolvedValue(jobRow),
        findMany: jest.fn().mockResolvedValue([]),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    instagramAdapter = { publish: jest.fn() };
    xAdapter = { publish: jest.fn().mockResolvedValue({ externalPostId: 'tweet_9' }) };
    facebookAdapter = { publish: jest.fn().mockResolvedValue({ externalPostId: 'fb_9' }) };
    threadsAdapter = { publish: jest.fn().mockResolvedValue({ externalPostId: 'th_9' }) };
    linkedinAdapter = { publish: jest.fn().mockResolvedValue({ externalPostId: 'li_9' }) };
    igQueue = { add: jest.fn().mockResolvedValue(undefined) };
    xQueue = { add: jest.fn().mockResolvedValue(undefined) };
    fbQueue = { add: jest.fn().mockResolvedValue(undefined) };
    thQueue = { add: jest.fn().mockResolvedValue(undefined) };
    liQueue = { add: jest.fn().mockResolvedValue(undefined) };

    service = new PublishingService(
      prisma as never,
      { decrypt: (v: string) => v.replace(/^ENC\(|\)$/g, '') } as never,
      instagramAdapter as never,
      xAdapter as never,
      facebookAdapter as never,
      threadsAdapter as never,
      linkedinAdapter as never,
      igQueue as never,
      xQueue as never,
      fbQueue as never,
      thQueue as never,
      liQueue as never,
    );
  });

  describe('publishNow — validate then enqueue (Milestone 7.2)', () => {
    it('creates a queued job and enqueues onto the account platform queue', async () => {
      const job = await service.publishNow('org_1', 'var_1', 'sa_1');

      expect(prisma.publishJob.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ status: 'queued' }) }),
      );
      // X account -> X queue only; Instagram queue untouched (isolation).
      expect(xQueue.add).toHaveBeenCalledTimes(1);
      expect(igQueue.add).not.toHaveBeenCalled();
      expect(job.status).toBe('queued');
    });

    it('does NOT call the platform adapter synchronously — that is the worker\'s job', async () => {
      await service.publishNow('org_1', 'var_1', 'sa_1');
      expect(xAdapter.publish).not.toHaveBeenCalled();
    });

    it('enqueues the job id, the request caption, and the retry policy', async () => {
      await service.publishNow('org_1', 'var_1', 'sa_1', 'Just this post');

      expect(xQueue.add).toHaveBeenCalledWith(
        'publish',
        { publishJobId: 'job_1', caption: 'Just this post' },
        PUBLISH_JOB_OPTIONS,
      );
    });

    it('uses the X queue name the processor is bound to', () => {
      expect(PUBLISH_QUEUES[Platform.x]).toBe('publish-x');
      expect(PUBLISH_QUEUES[Platform.instagram]).toBe('publish-instagram');
    });

    describe('preconditions reject before anything is queued', () => {
      const cases: Array<[string, () => void]> = [
        ['a variant that is not ready', () =>
          prisma.contentVariant.findUnique.mockResolvedValue({ ...readyVariant, status: 'pending' })],
        ['a variant with no rendered image', () =>
          prisma.contentVariant.findUnique.mockResolvedValue({ ...readyVariant, renderedMediaUrl: null })],
        ['a disconnected account', () =>
          prisma.socialAccount.findUnique.mockResolvedValue({ ...connectedAccount, status: 'revoked' })],
        ['a platform mismatch', () =>
          prisma.socialAccount.findUnique.mockResolvedValue({ ...connectedAccount, platform: Platform.instagram })],
      ];

      it.each(cases)('rejects %s and enqueues nothing', async (_label, arrange) => {
        arrange();
        await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
          UnprocessableEntityException,
        );
        expect(xQueue.add).not.toHaveBeenCalled();
        expect(igQueue.add).not.toHaveBeenCalled();
        expect(prisma.publishJob.create).not.toHaveBeenCalled();
      });

      it('404s another org\'s variant without probing further', async () => {
        prisma.contentVariant.findUnique.mockResolvedValue({
          ...readyVariant,
          asset: {
            orgId: 'other_org',
            approvalStatus: 'draft',
            organization: { requiresApproval: false },
          },
        });
        await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
          NotFoundException,
        );
        expect(xQueue.add).not.toHaveBeenCalled();
      });
    });

    describe('approval gate (Milestone 13.2)', () => {
      it('blocks an unapproved design when the org requires approval', async () => {
        prisma.contentVariant.findUnique.mockResolvedValue({
          ...readyVariant,
          asset: {
            orgId: 'org_1',
            approvalStatus: 'pending_approval',
            organization: { requiresApproval: true },
          },
        });
        await expect(service.publishNow('org_1', 'var_1', 'sa_1')).rejects.toThrow(
          /must be approved/i,
        );
        expect(xQueue.add).not.toHaveBeenCalled();
        expect(prisma.publishJob.create).not.toHaveBeenCalled();
      });

      it('allows an approved design in an approval-required org', async () => {
        prisma.contentVariant.findUnique.mockResolvedValue({
          ...readyVariant,
          asset: {
            orgId: 'org_1',
            approvalStatus: 'approved',
            organization: { requiresApproval: true },
          },
        });
        const job = await service.publishNow('org_1', 'var_1', 'sa_1');
        expect(job.status).toBe('queued');
        expect(xQueue.add).toHaveBeenCalledTimes(1);
      });

      it('ignores approval status entirely when the org does not require it', async () => {
        // readyVariant defaults to requiresApproval:false + draft — publishes fine.
        const job = await service.publishNow('org_1', 'var_1', 'sa_1');
        expect(job.status).toBe('queued');
      });
    });
  });

  describe('executePublish — the worker body (Milestone 7.2)', () => {
    const ctx = { attemptsMade: 0, maxAttempts: 3 };

    it('publishes through the adapter matching the account platform', async () => {
      await service.executePublish({ publishJobId: 'job_1' }, ctx);

      expect(xAdapter.publish).toHaveBeenCalledTimes(1);
      expect(instagramAdapter.publish).not.toHaveBeenCalled();
    });

    it('decrypts the stored token — the adapter must never see ciphertext', async () => {
      await service.executePublish({ publishJobId: 'job_1' }, ctx);
      expect(xAdapter.publish).toHaveBeenCalledWith(
        expect.objectContaining({ accessToken: 'token' }),
      );
    });

    it('marks the job published with the platform post id on success', async () => {
      await service.executePublish({ publishJobId: 'job_1' }, ctx);
      expect(prisma.publishJob.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'published', externalPostId: 'tweet_9' }),
        }),
      );
    });

    describe('caption resolution', () => {
      it('prefers the request caption', async () => {
        await service.executePublish({ publishJobId: 'job_1', caption: 'Fresh' }, ctx);
        expect(xAdapter.publish).toHaveBeenCalledWith(
          expect.objectContaining({ caption: 'Fresh' }),
        );
      });

      it('falls back to the variant caption when none supplied', async () => {
        await service.executePublish({ publishJobId: 'job_1' }, ctx);
        expect(xAdapter.publish).toHaveBeenCalledWith(
          expect.objectContaining({ caption: 'Hello world' }),
        );
      });

      it('treats an empty request caption as a deliberate "no caption"', async () => {
        await service.executePublish({ publishJobId: 'job_1', caption: '' }, ctx);
        expect(xAdapter.publish).toHaveBeenCalledWith(
          expect.objectContaining({ caption: '' }),
        );
      });
    });

    describe('retry and exhaustion', () => {
      it('on a non-final failure: records the error, stays processing, and rethrows', async () => {
        xAdapter.publish.mockRejectedValue(new Error('rate limited'));

        await expect(
          service.executePublish({ publishJobId: 'job_1' }, { attemptsMade: 0, maxAttempts: 3 }),
        ).rejects.toThrow('rate limited');

        // status must NOT be failed yet — more attempts remain.
        expect(prisma.publishJob.update).toHaveBeenLastCalledWith(
          expect.objectContaining({
            data: expect.objectContaining({ status: 'processing', lastError: 'rate limited' }),
          }),
        );
      });

      it('on the final failure: marks failed with the platform error, and rethrows', async () => {
        xAdapter.publish.mockRejectedValue(new Error('still failing'));

        await expect(
          service.executePublish({ publishJobId: 'job_1' }, { attemptsMade: 2, maxAttempts: 3 }),
        ).rejects.toThrow('still failing');

        expect(prisma.publishJob.update).toHaveBeenLastCalledWith(
          expect.objectContaining({
            data: expect.objectContaining({ status: 'failed', lastError: 'still failing' }),
          }),
        );
      });

      it('records the attempt number on each try', async () => {
        await service.executePublish({ publishJobId: 'job_1' }, { attemptsMade: 1, maxAttempts: 3 });
        // attemptsMade 1 -> this is attempt #2
        expect(prisma.publishJob.update).toHaveBeenCalledWith(
          expect.objectContaining({
            data: expect.objectContaining({ status: 'processing', attemptCount: 2 }),
          }),
        );
      });
    });

    describe('terminal, non-retryable states', () => {
      it('a vanished job is a no-op, not an error (nothing to retry)', async () => {
        prisma.publishJob.findUnique.mockResolvedValue(null);
        await expect(
          service.executePublish({ publishJobId: 'gone' }, ctx),
        ).resolves.toBeUndefined();
        expect(xAdapter.publish).not.toHaveBeenCalled();
      });

      it('a missing variant/account marks the job failed WITHOUT throwing (no point retrying)', async () => {
        prisma.contentVariant.findUnique.mockResolvedValue(null);

        await expect(
          service.executePublish({ publishJobId: 'job_1' }, ctx),
        ).resolves.toBeUndefined();

        expect(prisma.publishJob.update).toHaveBeenCalledWith(
          expect.objectContaining({ data: expect.objectContaining({ status: 'failed' }) }),
        );
        expect(xAdapter.publish).not.toHaveBeenCalled();
      });
    });
  });

  describe('schedule — future publish (Milestone 7.3)', () => {
    const future = new Date(Date.now() + 60 * 60 * 1000);

    it('records a scheduled job with its time and caption, and enqueues nothing', async () => {
      const job = await service.schedule('org_1', 'var_1', 'sa_1', future, 'later');

      expect(prisma.publishJob.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: 'scheduled',
            scheduledAt: future,
            caption: 'later',
          }),
        }),
      );
      expect(xQueue.add).not.toHaveBeenCalled();
      expect(job.status).toBe('queued'); // jobRow stub; real row would be scheduled
    });

    it('rejects a time in the past', async () => {
      const past = new Date(Date.now() - 1000);
      await expect(service.schedule('org_1', 'var_1', 'sa_1', past)).rejects.toThrow(
        UnprocessableEntityException,
      );
      expect(prisma.publishJob.create).not.toHaveBeenCalled();
    });

    it('applies the same preconditions as an immediate publish', async () => {
      prisma.socialAccount.findUnique.mockResolvedValue({
        ...connectedAccount,
        status: 'revoked',
      });
      await expect(service.schedule('org_1', 'var_1', 'sa_1', future)).rejects.toThrow(
        UnprocessableEntityException,
      );
    });
  });

  describe('dispatchDueScheduledJobs — the cron body (Milestone 7.3)', () => {
    const dueJob = {
      id: 'job_due',
      socialAccountId: 'sa_1',
      caption: 'scheduled caption',
      socialAccount: { platform: Platform.x },
    };

    it('claims a due job atomically and enqueues it onto its platform queue', async () => {
      prisma.publishJob.findMany.mockResolvedValue([dueJob]);
      prisma.publishJob.updateMany.mockResolvedValue({ count: 1 });

      const dispatched = await service.dispatchDueScheduledJobs(new Date());

      // Claim was gated on the row still being `scheduled`.
      expect(prisma.publishJob.updateMany).toHaveBeenCalledWith({
        where: { id: 'job_due', status: 'scheduled' },
        data: { status: 'queued' },
      });
      expect(xQueue.add).toHaveBeenCalledWith(
        'publish',
        { publishJobId: 'job_due', caption: 'scheduled caption' },
        PUBLISH_JOB_OPTIONS,
      );
      expect(dispatched).toBe(1);
    });

    it('does NOT enqueue a job it failed to claim — another tick got it first', async () => {
      prisma.publishJob.findMany.mockResolvedValue([dueJob]);
      prisma.publishJob.updateMany.mockResolvedValue({ count: 0 });

      const dispatched = await service.dispatchDueScheduledJobs(new Date());

      expect(xQueue.add).not.toHaveBeenCalled();
      expect(dispatched).toBe(0);
    });

    it('enqueues nothing when nothing is due', async () => {
      prisma.publishJob.findMany.mockResolvedValue([]);
      const dispatched = await service.dispatchDueScheduledJobs(new Date());
      expect(dispatched).toBe(0);
      expect(xQueue.add).not.toHaveBeenCalled();
    });
  });

  describe('findJobScoped', () => {
    it('returns a job that belongs to the org', async () => {
      prisma.publishJob.findUnique.mockResolvedValue({
        ...jobRow,
        socialAccount: { orgId: 'org_1' },
      });
      await expect(service.findJobScoped('job_1', 'org_1')).resolves.toBeTruthy();
    });

    it('404s a job belonging to another org', async () => {
      prisma.publishJob.findUnique.mockResolvedValue({
        ...jobRow,
        socialAccount: { orgId: 'other' },
      });
      await expect(service.findJobScoped('job_1', 'org_1')).rejects.toThrow(NotFoundException);
    });
  });

  describe('listJobs (Milestone 7.4)', () => {
    it('scopes to the org through the socialAccount relation, newest first', async () => {
      prisma.publishJob.findMany.mockResolvedValue([]);
      await service.listJobs('org_1');

      expect(prisma.publishJob.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { socialAccount: { orgId: 'org_1' } },
          orderBy: { createdAt: 'desc' },
        }),
      );
    });

    it('applies a status filter when given', async () => {
      prisma.publishJob.findMany.mockResolvedValue([]);
      await service.listJobs('org_1', 'scheduled' as never);

      expect(prisma.publishJob.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { socialAccount: { orgId: 'org_1' }, status: 'scheduled' },
        }),
      );
    });
  });

  describe('cancelScheduled (Milestone 7.4)', () => {
    function scopedJob(status: string) {
      return { ...jobRow, status, socialAccount: { orgId: 'org_1' } };
    }

    it('cancels a scheduled job atomically', async () => {
      prisma.publishJob.findUnique
        .mockResolvedValueOnce(scopedJob('scheduled')) // findJobScoped (guard)
        .mockResolvedValueOnce(scopedJob('cancelled')); // findJobScoped (return)
      prisma.publishJob.updateMany.mockResolvedValue({ count: 1 });

      await service.cancelScheduled('job_1', 'org_1');

      expect(prisma.publishJob.updateMany).toHaveBeenCalledWith({
        where: { id: 'job_1', status: 'scheduled' },
        data: { status: 'cancelled' },
      });
    });

    it('refuses to cancel a job that is no longer scheduled', async () => {
      prisma.publishJob.findUnique.mockResolvedValue(scopedJob('published'));
      await expect(service.cancelScheduled('job_1', 'org_1')).rejects.toThrow(
        UnprocessableEntityException,
      );
      expect(prisma.publishJob.updateMany).not.toHaveBeenCalled();
    });

    it('handles the cron claiming the job in the same instant (race)', async () => {
      prisma.publishJob.findUnique.mockResolvedValue(scopedJob('scheduled'));
      prisma.publishJob.updateMany.mockResolvedValue({ count: 0 });

      await expect(service.cancelScheduled('job_1', 'org_1')).rejects.toThrow(
        UnprocessableEntityException,
      );
    });

    it('404s another org\'s job without cancelling anything', async () => {
      prisma.publishJob.findUnique.mockResolvedValue({
        ...jobRow,
        status: 'scheduled',
        socialAccount: { orgId: 'other' },
      });
      await expect(service.cancelScheduled('job_1', 'org_1')).rejects.toThrow(NotFoundException);
      expect(prisma.publishJob.updateMany).not.toHaveBeenCalled();
    });
  });
});
