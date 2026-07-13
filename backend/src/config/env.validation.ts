import * as Joi from 'joi';

/**
 * Validated at application boot via ConfigModule.forRoot({ validationSchema }).
 * Any missing/invalid variable throws immediately on startup, before any
 * request is ever handled — per the blueprint's Milestone 0.3 requirement
 * ("env validated at boot").
 *
 * Extend this schema in the same commit that introduces a new required
 * env var (see .env.example, which documents the human-readable side of
 * the same contract).
 */
export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'test', 'staging', 'production')
    .default('development'),
  PORT: Joi.number().port().default(3000),

  // Was never added here despite being introduced in Milestone 0.4 — a
  // real gap, only surfaced now that PrismaService (this fix) reads it
  // directly via ConfigService rather than Prisma's own tooling picking
  // it up independently. Without this, a missing DATABASE_URL would have
  // failed with a cryptic Prisma/pg connection error instead of our own
  // clear boot-time validation message.
  DATABASE_URL: Joi.string().required(),

  // Access token (short-lived JWT, verified via passport-jwt strategy).
  // No default for the secret — a missing secret must fail boot loudly,
  // never silently fall back to a hardcoded value.
  JWT_ACCESS_SECRET: Joi.string().min(32).required(),
  JWT_ACCESS_EXPIRES_IN: Joi.string().default('15m'),

  // Refresh token (opaque random string, hashed at rest — see
  // src/auth/auth.service.ts). This only controls how long a stored
  // refresh_token row stays valid, not a JWT expiry.
  JWT_REFRESH_EXPIRES_IN_DAYS: Joi.number().integer().min(1).default(30),

  // AES-256-GCM key for TokenEncryptionService (Milestone 2.1) — must be
  // exactly 32 bytes, hex-encoded (64 hex characters). No default, same
  // reasoning as JWT_ACCESS_SECRET: a missing encryption key must fail
  // boot loudly, never silently fall back to something guessable.
  TOKEN_ENCRYPTION_KEY: Joi.string().hex().length(64).required(),
});
