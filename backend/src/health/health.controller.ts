import { Controller, Get } from '@nestjs/common';
import { readFileSync } from 'fs';
import { join } from 'path';

import { HealthResponseDto } from './health-response.dto';

/**
 * Resolves the app version without depending on __dirname's depth relative
 * to package.json.
 *
 * __dirname is NOT a safe basis for this: `nest start --watch` (dev) and
 * `node dist/main.js` (prod) both run compiled output from dist/, so
 * __dirname is always "dist/health" in every environment — there is no
 * "dev vs prod" __dirname difference to branch on, and package.json is
 * never copied into dist/. Walking up from __dirname was the bug.
 *
 * Instead:
 * 1. Prefer `npm_package_version`, which npm injects automatically into
 *    any process started via an `npm run <script>` — zero file I/O, and
 *    correct in both `start:dev` and `start:prod`.
 * 2. Fall back to reading package.json relative to process.cwd() — correct
 *    for `node dist/main.js` invoked directly (e.g. a Docker CMD that
 *    skips npm), as long as the process's working directory is the
 *    backend project root, which is the standard convention this repo
 *    follows (see Dockerfile in a later milestone).
 * 3. Never throw. A version lookup failing should never prevent the app
 *    from booting or take down the health endpoint — fall back to
 *    'unknown' instead.
 */
function resolveAppVersion(): string {
  if (process.env.npm_package_version) {
    return process.env.npm_package_version;
  }

  try {
    const packageJson = JSON.parse(
      readFileSync(join(process.cwd(), 'package.json'), 'utf-8'),
    ) as { version: string };
    return packageJson.version;
  } catch {
    return 'unknown';
  }
}

const appVersion = resolveAppVersion();

@Controller('health')
export class HealthController {
  @Get()
  check(): HealthResponseDto {
    return {
      status: 'ok',
      uptime: process.uptime(),
      version: appVersion,
    };
  }
}
