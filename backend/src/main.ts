import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';

import { AppModule } from './app.module';

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

  const configService = app.get(ConfigService);
  const port = configService.get<number>('PORT', 3000);

  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`SocialHub API listening on port ${port}`);
}

bootstrap();
