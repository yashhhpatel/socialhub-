/**
 * Securely creates or promotes a platform (super) admin — the operator account
 * for the /admin panel (Phase 21).
 *
 * Credentials come ONLY from the environment, never source/Git:
 *   PLATFORM_ADMIN_EMAIL     required
 *   PLATFORM_ADMIN_PASSWORD  required (min 8 chars, 1 number, 1 symbol)
 *   DATABASE_URL             required (loaded from backend/.env by dotenv)
 *
 * Run from backend/:  npm run seed:admin
 *
 * Idempotent: if the email already exists it is promoted (isPlatformAdmin=true,
 * password set to the provided one, email marked verified); otherwise a new
 * user + its own workspace are created. Safe to re-run.
 */
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const BCRYPT_SALT_ROUNDS = 12;
const PASSWORD_RULE = /^(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>_\-+=]).{8,}$/;

function defaultOrgName(email: string): string {
  const localPart = email.trim().toLowerCase().split('@')[0] || 'admin';
  return `${localPart}'s workspace`;
}

async function main(): Promise<void> {
  const email = process.env.PLATFORM_ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.PLATFORM_ADMIN_PASSWORD;
  const databaseUrl = process.env.DATABASE_URL;

  if (!email || !password) {
    throw new Error(
      'Set PLATFORM_ADMIN_EMAIL and PLATFORM_ADMIN_PASSWORD in the environment before seeding.',
    );
  }
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not set (expected in backend/.env).');
  }
  if (!PASSWORD_RULE.test(password)) {
    throw new Error(
      'PLATFORM_ADMIN_PASSWORD must be at least 8 chars with 1 number and 1 symbol.',
    );
  }

  const prisma = new PrismaClient({
    adapter: new PrismaPg({ connectionString: databaseUrl }),
  });

  try {
    const passwordHash = await bcrypt.hash(password, BCRYPT_SALT_ROUNDS);
    const existing = await prisma.user.findUnique({ where: { email } });

    if (existing) {
      await prisma.user.update({
        where: { id: existing.id },
        data: {
          isPlatformAdmin: true,
          passwordHash,
          emailVerifiedAt: existing.emailVerifiedAt ?? new Date(),
        },
      });
      // eslint-disable-next-line no-console
      console.log(`Promoted existing user to platform admin: ${email}`);
    } else {
      await prisma.$transaction(async (tx) => {
        const org = await tx.organization.create({
          data: { name: defaultOrgName(email) },
        });
        await tx.user.create({
          data: {
            email,
            passwordHash,
            orgId: org.id,
            role: UserRole.owner,
            isPlatformAdmin: true,
            emailVerifiedAt: new Date(),
          },
        });
      });
      // eslint-disable-next-line no-console
      console.log(`Created platform admin (with workspace): ${email}`);
    }
    // eslint-disable-next-line no-console
    console.log('Done. Log in at the app, then open /admin.');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
