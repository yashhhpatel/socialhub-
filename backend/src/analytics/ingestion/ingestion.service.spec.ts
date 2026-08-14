import { IngestionStatus, Platform } from '@prisma/client';

import { IngestionService } from './ingestion.service';

describe('IngestionService', () => {
  let service: IngestionService;
  let prisma: {
    ingestionRun: { create: jest.Mock; update: jest.Mock };
    publishJob: { findMany: jest.Mock };
    postMetric: { upsert: jest.Mock };
  };
  let tokenEncryption: { decrypt: jest.Mock };
  let metricFetcher: { fetchRaw: jest.Mock };

  const igJob = {
    id: 'job_ig',
    externalPostId: 'ig_post_1',
    socialAccount: { platform: Platform.instagram, accessTokenEnc: 'ENC(t1)' },
  };
  const xJob = {
    id: 'job_x',
    externalPostId: 'x_post_1',
    socialAccount: { platform: Platform.x, accessTokenEnc: 'ENC(t2)' },
  };

  beforeEach(() => {
    prisma = {
      ingestionRun: {
        create: jest.fn().mockResolvedValue({ id: 'run_1' }),
        update: jest.fn().mockResolvedValue({}),
      },
      publishJob: { findMany: jest.fn().mockResolvedValue([igJob, xJob]) },
      postMetric: { upsert: jest.fn().mockResolvedValue({}) },
    };
    tokenEncryption = { decrypt: jest.fn((v: string) => v.replace(/^ENC\(|\)$/g, '')) };
    metricFetcher = {
      fetchRaw: jest.fn(async (platform: Platform) =>
        platform === Platform.instagram
          ? { data: [{ name: 'likes', values: [{ value: 5 }] }] }
          : { data: { public_metrics: { impression_count: 100, like_count: 9 } } },
      ),
    };

    service = new IngestionService(
      prisma as never,
      tokenEncryption as never,
      metricFetcher as never,
    );
  });

  it('only pulls published posts with an id, on a connected account', async () => {
    await service.runIngestion();

    const where = prisma.publishJob.findMany.mock.calls[0][0].where;
    expect(where.status).toBe('published');
    expect(where.externalPostId).toEqual({ not: null });
    expect(where.socialAccount).toEqual({ status: 'connected' });
  });

  it('fetches, normalizes and upserts one PostMetric per post', async () => {
    const summary = await service.runIngestion();

    expect(summary.processed).toBe(2);
    expect(summary.failed).toBe(0);
    expect(prisma.postMetric.upsert).toHaveBeenCalledTimes(2);

    // The decrypted token — not the ciphertext — reaches the fetcher.
    expect(metricFetcher.fetchRaw).toHaveBeenCalledWith(Platform.instagram, 'ig_post_1', 't1');

    // Normalized numbers landed on the row (IG likes=5).
    const igUpsert = prisma.postMetric.upsert.mock.calls.find(
      (c) => c[0].where.publishJobId === 'job_ig',
    )![0];
    expect(igUpsert.create.likes).toBe(5);
    expect(igUpsert.update.likes).toBe(5);
  });

  it('marks the run success with the tallies', async () => {
    await service.runIngestion();

    const finalUpdate = prisma.ingestionRun.update.mock.calls.at(-1)![0];
    expect(finalUpdate.data.status).toBe(IngestionStatus.success);
    expect(finalUpdate.data.postsProcessed).toBe(2);
    expect(finalUpdate.data.postsFailed).toBe(0);
    expect(finalUpdate.data.finishedAt).toBeInstanceOf(Date);
  });

  it('counts a single failing post without aborting the whole run', async () => {
    metricFetcher.fetchRaw.mockImplementation(async (platform: Platform) => {
      if (platform === Platform.x) throw new Error('429 rate limited');
      return { data: [{ name: 'likes', values: [{ value: 5 }] }] };
    });

    const summary = await service.runIngestion();

    expect(summary.processed).toBe(1);
    expect(summary.failed).toBe(1);
    // Still a success run — individual post failures are expected and tallied.
    const finalUpdate = prisma.ingestionRun.update.mock.calls.at(-1)![0];
    expect(finalUpdate.data.status).toBe(IngestionStatus.success);
    expect(finalUpdate.data.postsFailed).toBe(1);
  });

  it('marks the run failed if the initial query throws', async () => {
    prisma.publishJob.findMany.mockRejectedValue(new Error('db down'));

    await expect(service.runIngestion()).rejects.toThrow('db down');

    const finalUpdate = prisma.ingestionRun.update.mock.calls.at(-1)![0];
    expect(finalUpdate.data.status).toBe(IngestionStatus.failed);
    expect(finalUpdate.data.error).toContain('db down');
  });
});
