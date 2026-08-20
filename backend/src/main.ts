import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';

import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { initSentry } from './common/observability/sentry';

async function bootstrap() {
  // rawBody enables req.rawBody for the Stripe webhook, whose signature is
  // computed over the exact raw payload (Phase 18). JSON parsing still applies
  // to every other route.
  const app = await NestFactory.create(AppModule, { rawBody: true });

  const configService = app.get(ConfigService);

  // Flutter Web (dev server on its own port) calls this API from a different
  // origin, so the browser enforces CORS. In production, set CORS_ORIGINS to a
  // comma-separated allowlist (e.g. "https://app.socialhub.com") and only those
  // origins are reflected — the credentialed, wildcard-reflect default below is
  // for local dev, where there's no fixed frontend origin to pin to (Phase
  // 17.2 hardening).
  const corsOrigins = (configService.get<string>('CORS_ORIGINS') ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter((o) => o.length > 0);
  app.enableCors({
    origin: corsOrigins.length > 0 ? corsOrigins : true,
    credentials: true,
  });

  // Global request validation, enforcing every DTO's class-validator
  // decorators (see src/auth/dto/*, src/users/dto/*). Not explicitly
  // named in Milestone 1.1's file list, but without this line the
  // decorators on RegisterDto/LoginDto/etc. are inert — requests would
  // reach the service layer unvalidated.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // strip unknown properties rather than rejecting
      forbidNonWhitelisted: true, // ...except reject if the client sent them
      transform: true, // payloads become real DTO class instances
    }),
  );

  // Global exception filter (Milestone 6.1). Turns every error — planned
  // HttpExceptions and unexpected ones alike — into the standard error
  // envelope, and stops unhandled errors from leaking a stack trace. Must
  // be registered after the ValidationPipe so validation's own
  // BadRequestException flows through it too.
  app.useGlobalFilters(new AllExceptionsFilter());

  // Error monitoring (Milestone 6.3). Initialised before the server starts
  // listening so nothing is served un-monitored. No-op without a SENTRY_DSN.
  initSentry(
    configService.get<string>('SENTRY_DSN'),
    configService.get<string>('NODE_ENV', 'development'),
  );

  const port = configService.get<number>('PORT', 3000);

  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`SocialHub API listening on port ${port}`);
}

bootstrap();
