// Prisma 7 configuration file — see https://pris.ly/d/config-datasource
//
// As of Prisma 7, schema.prisma no longer carries the connection URL; it's
// purely structural. This file is what `prisma migrate`, `prisma generate`,
// `prisma studio`, etc. read for environment-dependent settings, following
// the CLI's own generated template.
import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: env('DATABASE_URL'),
  },
});
