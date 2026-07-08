import { Module } from '@nestjs/common';
import { ConfigModule as NestConfigModule } from '@nestjs/config';

import { envValidationSchema } from './env.validation';

/**
 * Wraps @nestjs/config with our validation schema and marks it global, so
 * every other module can inject ConfigService without re-importing this
 * module. See docs/architecture/SocialHub_Architecture_Plan.md §7
 * (Backend Architecture) and the Milestone 0.3 blueprint entry.
 */
@Module({
  imports: [
    NestConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env'],
      validationSchema: envValidationSchema,
      validationOptions: {
        abortEarly: false,
      },
    }),
  ],
})
export class ConfigModule {}
