import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Invite, InviteStatus, User, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'crypto';

import { roleMeetsMinimum } from '../../common/constants/role-rank';
import { EmailService } from '../../common/email/email.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AcceptInviteDto } from './dto/accept-invite.dto';
import { CreateInviteDto } from './dto/create-invite.dto';

const BCRYPT_SALT_ROUNDS = 12;
const INVITE_TOKEN_BYTES = 32;
const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

/**
 * Team invitations (Milestone 11.1). Mirrors the refresh-token security
 * model: a random token goes out in the email, only its SHA-256 hash is
 * stored, and acceptance is single-use + time-bounded.
 */
@Injectable()
export class InvitesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Creates an invite and emails the accept link. `inviter` is the acting
   * user; the invited role is capped to their rank (no inviting above
   * yourself), and owner seats can't be handed out via invite at all —
   * ownership transfer is a deliberately separate concern.
   */
  async create(
    orgId: string,
    inviter: { userId: string; role: UserRole },
    dto: CreateInviteDto,
  ): Promise<Invite> {
    const email = dto.email.trim().toLowerCase();

    if (dto.role === UserRole.owner) {
      throw new BadRequestException('An org can only have one owner; owner cannot be invited.');
    }
    if (!roleMeetsMinimum(inviter.role, dto.role)) {
      throw new ForbiddenException('You cannot invite someone to a role higher than your own.');
    }

    // Already a member? Nothing to invite.
    const existingUser = await this.prisma.user.findUnique({ where: { email } });
    if (existingUser && existingUser.orgId === orgId) {
      throw new ConflictException('That person is already a member of this organization.');
    }

    // Supersede any outstanding pending invite for the same email+org, so a
    // re-invite issues a fresh single-use token rather than leaving two live.
    await this.prisma.invite.updateMany({
      where: { orgId, email, status: InviteStatus.pending },
      data: { status: InviteStatus.revoked },
    });

    const rawToken = randomBytes(INVITE_TOKEN_BYTES).toString('hex');
    const invite = await this.prisma.invite.create({
      data: {
        orgId,
        email,
        role: dto.role,
        tokenHash: this.hashToken(rawToken),
        invitedById: inviter.userId,
        expiresAt: new Date(Date.now() + INVITE_TTL_MS),
      },
    });

    const org = await this.prisma.organization.findUnique({ where: { id: orgId } });
    await this.email.sendInvite({
      to: email,
      inviteUrl: this.buildAcceptUrl(rawToken),
      orgName: org?.name ?? 'your team',
      role: dto.role,
    });

    return invite;
  }

  /** Pending invites for the team screen. */
  listPending(orgId: string): Promise<Invite[]> {
    return this.prisma.invite.findMany({
      where: { orgId, status: InviteStatus.pending },
      orderBy: { createdAt: 'desc' },
    });
  }

  async revoke(inviteId: string, orgId: string): Promise<void> {
    const invite = await this.prisma.invite.findUnique({ where: { id: inviteId } });
    // Same 404 for missing or another org's — never confirm an id exists
    // outside the caller's tenant.
    if (!invite || invite.orgId !== orgId) {
      throw new NotFoundException('Invite not found.');
    }
    await this.prisma.invite.update({
      where: { id: inviteId },
      data: { status: InviteStatus.revoked },
    });
  }

  /**
   * Accepts an invite: validates the token, creates a scoped user at the
   * invited role, and marks the invite used — all in one transaction so a
   * token can never mint two users.
   */
  async accept(rawToken: string, dto: AcceptInviteDto): Promise<User> {
    const invite = await this.prisma.invite.findUnique({
      where: { tokenHash: this.hashToken(rawToken) },
    });

    if (!invite || invite.status !== InviteStatus.pending) {
      throw new NotFoundException('This invitation is invalid or has already been used.');
    }
    if (invite.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException('This invitation has expired. Ask for a new one.');
    }

    const existingUser = await this.prisma.user.findUnique({ where: { email: invite.email } });
    if (existingUser) {
      throw new ConflictException('An account with this email already exists.');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_SALT_ROUNDS);

    return this.prisma.$transaction(async (tx) => {
      // Re-check + claim the invite atomically: the guard on status makes a
      // concurrent double-accept impossible.
      const claimed = await tx.invite.updateMany({
        where: { id: invite.id, status: InviteStatus.pending },
        data: { status: InviteStatus.accepted, acceptedAt: new Date() },
      });
      if (claimed.count !== 1) {
        throw new NotFoundException('This invitation is invalid or has already been used.');
      }

      return tx.user.create({
        data: {
          email: invite.email,
          passwordHash,
          orgId: invite.orgId,
          role: invite.role,
        },
      });
    });
  }

  private hashToken(rawToken: string): string {
    return createHash('sha256').update(rawToken).digest('hex');
  }

  private buildAcceptUrl(rawToken: string): string {
    const frontend = this.config.get<string>('FRONTEND_URL');
    // Hash route, matching how the OAuth callbacks build frontend URLs
    // (go_router's default hash strategy — see social-accounts.controller).
    if (frontend) return `${frontend}/#/accept-invite?token=${rawToken}`;
    // No frontend configured (API-only dev): return a path the accept
    // endpoint understands directly.
    return `/invites/${rawToken}/accept`;
  }
}
