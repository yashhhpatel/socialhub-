import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

import { PrismaService } from '../prisma/prisma.service';

/**
 * GDPR account-lifecycle operations (Phase 17.4): export a user's data, and
 * permanently delete an account.
 *
 * Deletion is deliberately an explicit, ordered transaction rather than a
 * blanket schema of ON DELETE CASCADE: most org relations are Restrict by
 * design (a stray cascade is how you lose data you meant to keep), so we
 * delete children before parents in dependency order, all-or-nothing.
 *
 *  - An OWNER deleting their account deletes the whole organization and every
 *    row scoped to it (this app creates one org per owner at registration).
 *  - A NON-owner deletes only their own membership and the data attributable
 *    to them (their authored comments and the designs they created), leaving
 *    the rest of the org intact.
 *
 * Tokens/secrets are never included in an export.
 */
@Injectable()
export class AccountDataService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Assemble a JSON-serialisable snapshot of everything we hold that's
   * attributable to this user (and, for an owner, their organization). Access
   * tokens and password hashes are deliberately excluded.
   */
  async exportData(userId: string): Promise<Record<string, unknown>> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { organization: true },
    });
    if (!user) throw new UnauthorizedException();

    const [connectedAccounts, designs, templates, comments] = await Promise.all([
      this.prisma.socialAccount.findMany({
        where: { orgId: user.orgId },
        // Explicit select — never leak the encrypted token columns.
        select: {
          id: true,
          platform: true,
          externalAccountId: true,
          externalUserId: true,
          status: true,
          createdAt: true,
        },
      }),
      this.prisma.contentAsset.findMany({
        where: { createdById: userId },
        select: {
          id: true,
          type: true,
          approvalStatus: true,
          masterImageUrl: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
      this.prisma.template.findMany({
        where: { orgId: user.orgId },
        select: {
          id: true,
          name: true,
          category: true,
          isPublic: true,
          createdAt: true,
        },
      }),
      this.prisma.comment.findMany({
        where: { authorId: userId },
        select: { id: true, assetId: true, body: true, createdAt: true },
      }),
    ]);

    return {
      exportedAt: new Date().toISOString(),
      account: {
        id: user.id,
        email: user.email,
        role: user.role,
        emailVerified: user.emailVerifiedAt !== null,
        mfaEnabled: user.mfaEnabled,
        createdAt: user.createdAt,
      },
      organization: {
        id: user.organization.id,
        name: user.organization.name,
        planTier: user.organization.planTier,
        createdAt: user.organization.createdAt,
      },
      connectedAccounts,
      designs,
      templates,
      comments,
    };
  }

  /**
   * Permanently delete the account after re-confirming the password. Returns
   * what was removed so the caller can log/report it. Irreversible.
   */
  async deleteAccount(
    userId: string,
    password: string,
  ): Promise<{ scope: 'organization' | 'user' }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();

    // Re-auth: deletion is destructive and irreversible, so require the
    // current password even though the caller already holds a valid token.
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) throw new BadRequestException('Password is incorrect.');

    if (user.role === UserRole.owner) {
      await this.deleteOrganization(user.orgId);
      return { scope: 'organization' };
    }

    await this.deleteMembership(userId);
    return { scope: 'user' };
  }

  /**
   * Delete an entire organization and everything scoped to it, children first.
   * Ordering matters: ContentAssets are removed before SocialAccounts because
   * PublishJob→SocialAccount is Restrict, and Users last because Comments/
   * ContentAssets (Restrict → User) must be gone before a User can be deleted.
   */
  private deleteOrganization(orgId: string): Promise<unknown> {
    return this.prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      // Cascades ContentVariant → PublishJob → PostMetric, and Comments.
      await tx.contentAsset.deleteMany({ where: { orgId } });
      await tx.socialAccount.deleteMany({ where: { orgId } });
      await tx.template.deleteMany({ where: { orgId } });
      await tx.brandKit.deleteMany({ where: { orgId } });
      await tx.aIUsageLog.deleteMany({ where: { orgId } });
      await tx.auditLog.deleteMany({ where: { orgId } });
      await tx.invite.deleteMany({ where: { orgId } });
      await tx.ssoConfig.deleteMany({ where: { orgId } });
      // Cascades RefreshToken, UserToken, MfaRecoveryCode per user.
      await tx.user.deleteMany({ where: { orgId } });
      await tx.organization.delete({ where: { id: orgId } });
    });
  }

  /**
   * Delete one member's account and the data attributable to them, leaving the
   * org intact. Their authored comments and created designs go first (both are
   * Restrict → User), then the user (cascading their tokens/MFA).
   */
  private deleteMembership(userId: string): Promise<unknown> {
    return this.prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      await tx.comment.deleteMany({ where: { authorId: userId } });
      // Cascades this user's designs' variants → jobs → metrics, and comments.
      await tx.contentAsset.deleteMany({ where: { createdById: userId } });
      await tx.user.delete({ where: { id: userId } });
    });
  }
}
