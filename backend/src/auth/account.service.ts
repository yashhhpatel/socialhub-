import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UserToken, UserTokenType } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'crypto';

import { EmailService } from '../common/email/email.service';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';

const BCRYPT_SALT_ROUNDS = 12;
const TOKEN_BYTES = 32;

// How long each single-use link stays valid. Verification is generous (a user
// may open it the next day); reset is short because it's a live credential
// change and a stolen link is higher-stakes.
const EMAIL_VERIFICATION_TTL_MS = 24 * 60 * 60 * 1000; // 24h
const PASSWORD_RESET_TTL_MS = 60 * 60 * 1000; // 1h

/**
 * Account-lifecycle flows that hang off auth but aren't the login/refresh core
 * (Phase 17.1): email verification and password reset. Both mint a one-time,
 * single-use [UserToken] whose raw value is emailed and whose SHA-256 hash is
 * all the DB ever stores — the same model RefreshToken uses, so a database read
 * never yields a usable link.
 *
 * Deliberate privacy stance: the password-reset *request* endpoint never
 * reveals whether an email is registered — it responds identically either way,
 * and this service simply does nothing for an unknown address. Enumeration of
 * accounts via the reset form is a real, common leak; closing it here is
 * cheaper than any downstream mitigation.
 */
@Injectable()
export class AccountService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly usersService: UsersService,
    private readonly email: EmailService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Issues a fresh verification link and emails it. Called right after
   * registration and by the authenticated resend endpoint. Any still-valid
   * verification tokens for the user are invalidated first so only the newest
   * link works — a resend shouldn't leave older links live.
   */
  async sendVerificationEmail(userId: string, emailAddress: string): Promise<void> {
    const rawToken = await this.issueToken(userId, UserTokenType.email_verification, EMAIL_VERIFICATION_TTL_MS);
    await this.email.sendEmailVerification({
      to: emailAddress,
      verifyUrl: this.buildFrontendUrl('verify-email', rawToken),
    });
  }

  /** Consumes a verification token and marks the user's email verified. */
  async verifyEmail(rawToken: string): Promise<void> {
    const token = await this.consumeToken(rawToken, UserTokenType.email_verification);
    await this.prisma.user.update({
      where: { id: token.userId },
      data: { emailVerifiedAt: new Date() },
    });
  }

  /**
   * Starts a password reset. Silent no-op for an unknown email (see class
   * doc) — the controller responds 200 regardless. Older reset tokens are
   * invalidated so only the latest link works.
   */
  async requestPasswordReset(emailAddress: string): Promise<void> {
    const user = await this.usersService.findByEmail(emailAddress);
    if (!user) return;

    const rawToken = await this.issueToken(user.id, UserTokenType.password_reset, PASSWORD_RESET_TTL_MS);
    await this.email.sendPasswordReset({
      to: user.email,
      resetUrl: this.buildFrontendUrl('reset-password', rawToken),
    });
  }

  /**
   * Consumes a reset token and sets the new password. Every existing session
   * is revoked (a password change must log other devices out), and the reset
   * also proves email ownership, so an unverified account becomes verified.
   */
  async resetPassword(rawToken: string, newPassword: string): Promise<void> {
    const token = await this.consumeToken(rawToken, UserTokenType.password_reset);
    const passwordHash = await bcrypt.hash(newPassword, BCRYPT_SALT_ROUNDS);

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: token.userId },
        data: { passwordHash, emailVerifiedAt: new Date() },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId: token.userId, revoked: false },
        data: { revoked: true },
      }),
    ]);
  }

  /**
   * Mints a token of the given type, invalidating any earlier unconsumed
   * tokens of that same type for the user (a resend supersedes prior links).
   * Returns the RAW token — the only place it ever exists in the clear.
   */
  private async issueToken(
    userId: string,
    type: UserTokenType,
    ttlMs: number,
  ): Promise<string> {
    const rawToken = randomBytes(TOKEN_BYTES).toString('hex');

    await this.prisma.$transaction([
      // Supersede older still-open links of the same type.
      this.prisma.userToken.updateMany({
        where: { userId, type, consumedAt: null },
        data: { consumedAt: new Date() },
      }),
      this.prisma.userToken.create({
        data: {
          userId,
          type,
          tokenHash: this.hashToken(rawToken),
          expiresAt: new Date(Date.now() + ttlMs),
        },
      }),
    ]);

    return rawToken;
  }

  /**
   * Validates a raw token against its stored hash and marks it consumed —
   * atomically, so a token can't be redeemed twice even under a race. Throws a
   * single generic BadRequestException for every failure (unknown, wrong type,
   * expired, already used) so a caller can't distinguish them.
   */
  private async consumeToken(rawToken: string, type: UserTokenType): Promise<UserToken> {
    const invalid = new BadRequestException('This link is invalid or has expired.');
    if (!rawToken) throw invalid;

    const token = await this.prisma.userToken.findUnique({
      where: { tokenHash: this.hashToken(rawToken) },
    });

    if (
      !token ||
      token.type !== type ||
      token.consumedAt !== null ||
      token.expiresAt < new Date()
    ) {
      throw invalid;
    }

    // Guarded update: only succeeds if still unconsumed. If a concurrent
    // request consumed it first, count is 0 and we reject — no double redemption.
    const result = await this.prisma.userToken.updateMany({
      where: { id: token.id, consumedAt: null },
      data: { consumedAt: new Date() },
    });
    if (result.count === 0) throw invalid;

    return token;
  }

  private hashToken(rawToken: string): string {
    return createHash('sha256').update(rawToken).digest('hex');
  }

  private buildFrontendUrl(route: string, rawToken: string): string {
    const frontend = this.config.get<string>('FRONTEND_URL');
    // Hash route, matching invites and the OAuth callbacks (go_router's
    // default hash strategy).
    if (frontend) return `${frontend}/#/${route}?token=${rawToken}`;
    // API-only dev: a path the caller can POST back with the token.
    return `/auth/${route}?token=${rawToken}`;
  }
}
