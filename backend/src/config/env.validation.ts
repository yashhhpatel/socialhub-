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
});
