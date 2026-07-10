import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import { execSync } from 'child_process';

import { AppModule } from './app.module';

async function bootstrap() {
  // --- TEMPORARY DIAGNOSTIC LOGGING ---
  // Prints which exact source tree is actually running, to rule out a
  // stale/duplicate project copy before debugging anything else. Remove
  // once the Prisma initialization issue is confirmed resolved.
  // eslint-disable-next-line no-console
  console.log('[bootstrap diagnostic] running from:', __dirname);
  try {
    const commit = execSync('git rev-parse HEAD', { cwd: __dirname })
      .toString()
      .trim();
    // eslint-disable-next-line no-console
    console.log('[bootstrap diagnostic] git HEAD commit:', commit);
  } catch {
    // eslint-disable-next-line no-console
    console.log(
      '[bootstrap diagnostic] could not read git HEAD (not a git repo from this cwd, or git unavailable)',
    );
  }

  const app = await NestFactory.create(AppModule);

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
