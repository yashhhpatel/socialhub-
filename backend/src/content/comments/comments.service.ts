import { Injectable } from '@nestjs/common';
import { Comment, User } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ContentService } from '../content.service';

export type CommentWithAuthor = Comment & { author: Pick<User, 'id' | 'email'> };

/**
 * Comment threads on a design (Milestone 13.1). Every operation is
 * org-scoped THROUGH the asset: the comment has no orgId of its own, so we
 * resolve the asset with ContentService.findByIdScoped first, which 404s an
 * asset outside the caller's org before any comment is read or written.
 */
@Injectable()
export class CommentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly content: ContentService,
  ) {}

  async create(
    orgId: string,
    assetId: string,
    authorId: string,
    body: string,
  ): Promise<CommentWithAuthor> {
    await this.content.findByIdScoped(assetId, orgId); // 404s another org's asset
    return this.prisma.comment.create({
      data: { assetId, authorId, body },
      include: { author: { select: { id: true, email: true } } },
    });
  }

  async list(orgId: string, assetId: string): Promise<CommentWithAuthor[]> {
    await this.content.findByIdScoped(assetId, orgId);
    return this.prisma.comment.findMany({
      where: { assetId },
      include: { author: { select: { id: true, email: true } } },
      orderBy: { createdAt: 'asc' }, // oldest first — a thread reads top-down
    });
  }
}
