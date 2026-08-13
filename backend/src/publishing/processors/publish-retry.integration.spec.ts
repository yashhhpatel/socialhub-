import { Queue, Worker } from 'bullmq';

/**
 * Proves the QUEUE mechanics the publish workers depend on (Milestone 7.2),
 * against a real Redis: a processor that throws is retried with backoff, and
 * the job lands in `completed` if a later attempt succeeds or `failed` once
 * attempts are exhausted. This is the queue-level counterpart to the
 * executePublish unit tests — it confirms that "throw to retry" actually
 * drives BullMQ the way the worker assumes.
 */
describe('Publish queue retry mechanics (BullMQ + Redis)', () => {
  const connection = {
    host: process.env.REDIS_HOST ?? 'localhost',
    port: Number(process.env.REDIS_PORT ?? 6379),
    password: process.env.REDIS_PASSWORD || undefined,
    maxRetriesPerRequest: null as null,
  };
  // Short, fixed backoff so the test isn't waiting on exponential delays.
  const jobOptions = { attempts: 3, backoff: { type: 'fixed' as const, delay: 50 } };

  let queue: Queue;
  let worker: Worker;

  afterEach(async () => {
    await worker?.close();
    await queue?.obliterate({ force: true }).catch(() => undefined);
    await queue?.close();
  });

  function uniqueName(suffix: string) {
    return `retry-${suffix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  it('retries a failing job and completes once an attempt succeeds', async () => {
    const name = uniqueName('recover');
    queue = new Queue(name, { connection });

    const attempts: number[] = [];
    const completed = new Promise<void>((resolve, reject) => {
      worker = new Worker(
        name,
        async (job) => {
          attempts.push(job.attemptsMade);
          // Fail the first two attempts (attemptsMade 0, 1), succeed on the third.
          if (job.attemptsMade < 2) throw new Error(`transient ${job.attemptsMade}`);
        },
        { connection },
      );
      worker.on('completed', () => resolve());
      worker.on('failed', (job) => {
        if (job && job.attemptsMade >= jobOptions.attempts) {
          reject(new Error('exhausted instead of recovering'));
        }
      });
    });

    await queue.add('publish', { publishJobId: 'x' }, jobOptions);
    await completed;

    // Saw three attempts (0, 1, 2), the third of which succeeded.
    expect(attempts).toEqual([0, 1, 2]);
  }, 20000);

  it('exhausts retries and marks the job failed after the final attempt', async () => {
    const name = uniqueName('exhaust');
    queue = new Queue(name, { connection });

    const seen: number[] = [];
    const exhausted = new Promise<number>((resolve) => {
      worker = new Worker(
        name,
        async (job) => {
          seen.push(job.attemptsMade);
          throw new Error('always fails');
        },
        { connection },
      );
      worker.on('failed', (job) => {
        if (job && job.attemptsMade >= jobOptions.attempts) resolve(job.attemptsMade);
      });
    });

    await queue.add('publish', { publishJobId: 'y' }, jobOptions);
    const finalAttempts = await exhausted;

    // Exactly three attempts made (0, 1, 2 during processing), terminal at 3.
    expect(seen).toEqual([0, 1, 2]);
    expect(finalAttempts).toBe(3);
  }, 20000);
});
