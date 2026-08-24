import { Injectable, NotFoundException } from '@nestjs/common';

import { AccountService } from '../auth/account.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  AdminUserDetailDto,
  AdminUserListDto,
} from './dto/admin-users.dto';

const MAX_LIMIT = 100;

// Selected from the DB to DERIVE sign-in method, never returned as-is.
const LIST_SELECT = {
  id: true,
  email: true,
  role: true,
  orgId: true,
  emailVerifiedAt: true,
  mfaEnabled: true,
  isPlatformAdmin: true,
  googleId: true, // presence only → hasGoogle
  passwordHash: true, // presence only → hasPassword
  createdAt: true,
  organization: { select: { name: true } },
} as const;

/**
 * Cross-tenant user administration (Phase 21.4). Reads never expose secrets:
 * `googleId`/`passwordHash` are selected only to derive booleans. Safe actions
 * (resend verification, force password reset) reuse AccountService — the same
 * flows the user could trigger themselves; the admin never sees or sets a
 * password.
 */
@Injectable()
export class AdminUsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly account: AccountService,
  ) {}

  async list(params: {
    search?: string;
    page?: number;
    limit?: number;
  }): Promise<AdminUserListDto> {
    const page = Math.max(1, params.page ?? 1);
    const limit = Math.min(MAX_LIMIT, Math.max(1, params.limit ?? 20));
    const search = params.search?.trim();

    const where = search
      ? { email: { contains: search.toLowerCase(), mode: 'insensitive' as const } }
      : {};

    const [total, rows] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: LIST_SELECT,
      }),
    ]);

    return {
      total,
      page,
      limit,
      data: rows.map((u) => this.toListItem(u)),
    };
  }

  async detail(userId: string): Promise<AdminUserDetailDto> {
    const u = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        ...LIST_SELECT,
        updatedAt: true,
        organization: { select: { name: true, planTier: true } },
      },
    });
    if (!u) throw new NotFoundException('User not found.');

    return {
      ...this.toListItem(u),
      orgPlanTier: u.organization.planTier,
      updatedAt: u.updatedAt,
    };
  }

  /** Re-sends the email-verification link to the user (safe, idempotent). */
  async resendVerification(userId: string): Promise<void> {
    const user = await this.requireUser(userId);
    await this.account.sendVerificationEmail(user.id, user.email);
  }

  /** Sends the user a password-reset link. The admin never sets the password. */
  async forcePasswordReset(userId: string): Promise<void> {
    const user = await this.requireUser(userId);
    await this.account.requestPasswordReset(user.email);
  }

  private async requireUser(userId: string): Promise<{ id: string; email: string }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true },
    });
    if (!user) throw new NotFoundException('User not found.');
    return user;
  }

  private toListItem(u: {
    id: string;
    email: string;
    role: string;
    orgId: string;
    emailVerifiedAt: Date | null;
    mfaEnabled: boolean;
    isPlatformAdmin: boolean;
    googleId: string | null;
    passwordHash: string | null;
    createdAt: Date;
    organization: { name: string };
  }) {
    return {
      id: u.id,
      email: u.email,
      role: u.role,
      orgId: u.orgId,
      orgName: u.organization.name,
      emailVerified: u.emailVerifiedAt !== null,
      mfaEnabled: u.mfaEnabled,
      isPlatformAdmin: u.isPlatformAdmin,
      hasPassword: u.passwordHash !== null,
      hasGoogle: u.googleId !== null,
      createdAt: u.createdAt,
    };
  }
}
