import { Injectable, Logger } from '@nestjs/common';
import { Notification } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

/// Known notification type slugs (the UI maps each to an icon). Kept as a union
/// so producers can't typo a type.
export type NotificationType =
  | 'publish_succeeded'
  | 'publish_failed'
  | 'invite_accepted'
  | 'approval_requested'
  | 'approval_approved'
  | 'approval_rejected';

/// In-app notifications (Phase 19): create + read/unread queries. Creation is
/// deliberately best-effort at the call sites (a notification failing must
/// never break the action that triggered it) — see `notifySafe`.
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  create(params: {
    userId: string;
    type: NotificationType;
    title: string;
    body: string;
    linkPath?: string;
  }): Promise<Notification> {
    return this.prisma.notification.create({
      data: {
        userId: params.userId,
        type: params.type,
        title: params.title,
        body: params.body,
        linkPath: params.linkPath ?? null,
      },
    });
  }

  /// Fire-and-forget create that swallows (and logs) failures — for use from
  /// event producers (publish worker, invite accept) where a notification
  /// hiccup must not fail the primary operation.
  async notifySafe(params: {
    userId: string;
    type: NotificationType;
    title: string;
    body: string;
    linkPath?: string;
  }): Promise<void> {
    try {
      await this.create(params);
    } catch (err) {
      this.logger.warn(
        `Failed to create ${params.type} notification for ${params.userId}: ${
          err instanceof Error ? err.message : err
        }`,
      );
    }
  }

  listForUser(userId: string, limit = 30): Promise<Notification[]> {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  unreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({
      where: { userId, readAt: null },
    });
  }

  /// Marks one notification read — scoped to the owner so a user can't mark
  /// someone else's. Idempotent (only flips still-unread rows).
  async markRead(id: string, userId: string): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { id, userId, readAt: null },
      data: { readAt: new Date() },
    });
  }

  async markAllRead(userId: string): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
  }

  /// Permanently removes one notification — scoped to the owner so a user can
  /// only delete their own. Idempotent: deleting a row that's already gone (or
  /// belongs to someone else) is a silent no-op rather than an error.
  async delete(id: string, userId: string): Promise<void> {
    await this.prisma.notification.deleteMany({
      where: { id, userId },
    });
  }
}
