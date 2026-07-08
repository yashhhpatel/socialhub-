import { Controller, Get } from '@nestjs/common';
import { readFileSync } from 'fs';
import { join } from 'path';

import { HealthResponseDto } from './health-response.dto';

const packageJson = JSON.parse(
  readFileSync(join(__dirname, '..', '..', 'package.json'), 'utf-8'),
) as { version: string };

@Controller('health')
export class HealthController {
  @Get()
  check(): HealthResponseDto {
    return {
      status: 'ok',
      uptime: process.uptime(),
      version: packageJson.version,
    };
  }
}
