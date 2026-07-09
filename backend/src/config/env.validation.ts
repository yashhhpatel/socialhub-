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

  // Access token (short-lived JWT, verified via passport-jwt strategy).
  // No default for the secret — a missing secret must fail boot loudly,
  // never silently fall back to a hardcoded value.
  JWT_ACCESS_SECRET: Joi.string().min(32).required(),
  JWT_ACCESS_EXPIRES_IN: Joi.string().default('15m'),

  // Refresh token (opaque random string, hashed at rest — see
  // src/auth/auth.service.ts). This only controls how long a stored
  // refresh_token row stays valid, not a JWT expiry.
  JWT_REFRESH_EXPIRES_IN_DAYS: Joi.number().integer().min(1).default(30),
});
