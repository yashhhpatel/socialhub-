import { Queue, Worker } from 'bullmq';

/**
 * Milestone 7.1's definition of done: "a test job can be enqueued and
 * processed locally." This is an INTEGRATION test — it talks to a real
 * Redis (the docker-compose `redis` service locally, a service container in
 * CI), because the thing being proven is precisely that BullMQ + Redis are
 * wired up, which a mock cannot demonstrate.
 */
describe('Queue infrastructure (BullMQ + Redis)', () => {
  const connection = {
    host: process.env.REDIS_HOST ?? 'localhost',
    port: Number(process.env.REDIS_PORT ?? 6379),
    password: process.env.REDIS_PASSWORD || undefined,
    // Fail fast rather than let ioredis retry forever if Redis is down —
    // a missing Redis should surface as a clear test failure, not a hang.
    maxRetriesPerRequest: null as null,
    enableReadyCheck: true,
  };

  // A unique queue name per run so parallel runs / leftover jobs can't
  // bleed into this assertion.
  const queueName = `test-${Date.now()}-${Math.random().toString(16).slice(2)}`;

  let queue: Queue;
  let worker: Worker;

  afterEach(async () => {
    await worker?.close();
    await queue?.obliterate({ force: true }).catch(() => undefined);
    await queue?.close();
  });

  it('processes a job that was enqueued, receiving its payload intact', async () => {
    queue = new Queue(queueName, { connection });

    // The worker resolves this promise with whatever it processed, so the
    // test can assert the round trip rather than just that it didn't throw.
    const processed = new Promise<{ assetId: string }>((resolve, reject) => {
      worker = new Worker<{ assetId: string }>(
        queueName,
        async (job) => {
          resolve(job.data);
          return job.data;
        },
        { connection },
      );
      worker.on('failed', (_job, err) => reject(err));
    });

    await queue.add('publish', { assetId: 'ast_42' });

    await expect(processed).resolves.toEqual({ assetId: 'ast_42' });
  }, 20000);
});
