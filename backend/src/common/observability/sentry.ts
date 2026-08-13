import { Logger } from '@nestjs/common';
import * as Sentry from '@sentry/node';

const logger = new Logger('Sentry');

/**
 * Initialises Sentry error monitoring (Milestone 6.3).
 *
 * Optional at boot, exactly like the Cloudinary, OAuth, and Anthropic
 * credentials: with no SENTRY_DSN the app runs fine and simply reports
 * nothing. This is what lets the same build run locally (no DSN) and on
 * staging (DSN set as a platform env var) with no code difference.
 *
 * Because `Sentry.captureException` is a no-op when the SDK was never
 * initialised, callers never have to guard their capture calls — see
 * AllExceptionsFilter, which calls it unconditionally.
 *
 * @returns whether monitoring was actually turned on.
 */
export function initSentry(dsn: string | undefined, environment: string): boolean {
  if (!dsn) {
    logger.log('SENTRY_DSN not set — error monitoring is disabled.');
    return false;
  }

  Sentry.init({
    dsn,
    environment,
    // Report every unhandled error, but sample performance traces lightly —
    // full tracing is expensive and not what this milestone needs.
    tracesSampleRate: 0.1,
  });

  logger.log(`Error monitoring enabled for environment "${environment}".`);
  return true;
}
