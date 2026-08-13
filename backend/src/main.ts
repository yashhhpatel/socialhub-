import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';

import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { initSentry } from './common/observability/sentry';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Flutter Web (dev server on its own port) calls this API from a
  // different origin, so the browser enforces CORS. Permissive for now
  // (reflects any origin) since there's no deployed environment yet to
  // scope this to specific domains — tightening this per-environment is
  // exactly the kind of thing the Phase 6 hardening pass exists for, not
  // something to guess at prematurely here.
  app.enableCors({
    origin: true,
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

  const configService = app.get(ConfigService);

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
