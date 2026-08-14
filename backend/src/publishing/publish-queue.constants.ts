import { Platform } from '@prisma/client';

/**
 * One queue per platform (Milestone 7.2).
 *
 * Isolation is the whole point: a Meta outage that stalls Instagram jobs
 * must not back up X publishing. Separate queues mean separate workers and
 * separate retry timelines, so a failing platform degrades only itself.
 *
 * Phase 8 completes the set: all five platforms now have an isolated queue
 * and worker.
 */
export const PUBLISH_QUEUES = {
  [Platform.instagram]: 'publish-instagram',
  [Platform.x]: 'publish-x',
  [Platform.facebook]: 'publish-facebook',
  [Platform.threads]: 'publish-threads',
  [Platform.linkedin]: 'publish-linkedin',
} as const;

export type PublishQueueName =
  (typeof PUBLISH_QUEUES)[keyof typeof PUBLISH_QUEUES];

/** What a publish job carries. The caption override rides with the attempt. */
export interface PublishJobData {
  publishJobId: string;
  caption?: string;
}

/**
 * Retry policy for a publish attempt.
 *
 * Exponential backoff because platform failures are usually transient
 * (rate limits, brief 5xxs) and retrying immediately just burns an attempt
 * against a limit that hasn't reset. THREE attempts total, not more:
 * publishing is not idempotent, so every retry is a real double-post risk
 * if a "failure" was actually an ambiguous timeout — the ceiling is
 * deliberately low, and the adapters/queue only retry on errors the
 * platform reported as failures, never on ambiguous ones.
 */
export const PUBLISH_JOB_OPTIONS = {
  attempts: 3,
  backoff: { type: 'exponential' as const, delay: 5000 },
};
