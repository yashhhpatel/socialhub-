/// BullMQ queue that runs the proactive social-token refresh sweep (Phase 20).
export const TOKEN_REFRESH_QUEUE = 'token-refresh';

/// Id of the single repeatable sweep job, so re-adding it on every boot is
/// idempotent (BullMQ dedupes repeatable jobs by name + repeat options, and a
/// stable jobId keeps the record stable).
export const TOKEN_REFRESH_JOB = 'token-refresh-sweep';

/// How often the sweep runs. Tokens are refreshed within a 24h window, so a
/// few sweeps per day comfortably catches everything before expiry.
export const TOKEN_REFRESH_CRON = '0 */6 * * *'; // every 6 hours
