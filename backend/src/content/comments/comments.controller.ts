import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CommentsService, CommentWithAuthor } from './comments.service';
import { CommentDto, CreateCommentDto } from './dto/create-comment.dto';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: UserRole; orgId: string };
}

function toDto(c: CommentWithAuthor): CommentDto {
  return {
    id: c.id,
    body: c.body,
    authorId: c.author.id,
    authorEmail: c.author.email,
    createdAt: c.createdAt,
  };
}

/**
 * Comment threads on a design (Milestone 13.1). Posting a comment is gated
 * at viewer+ — i.e. every authenticated member of the org can leave feedback,
 * including viewers, since collaboration shouldn't require edit rights. The
 * explicit @Roles(viewer) keeps the "every mutating route declares a role"
 * invariant (see the RBAC matrix) rather than leaving the route ungated.
 */
@Controller('content/assets/:assetId/comments')
export class CommentsController {
  constructor(private readonly comments: CommentsService) {}

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.viewer)
  @Post()
  async create(
    @Req() req: AuthenticatedRequest,
    @Param('assetId') assetId: string,
    @Body() dto: CreateCommentDto,
  ): Promise<CommentDto> {
    const comment = await this.comments.create(
      req.user.orgId,
      assetId,
      req.user.userId,
      dto.body,
    );
    return toDto(comment);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  async list(
    @Req() req: AuthenticatedRequest,
    @Param('assetId') assetId: string,
  ): Promise<CommentDto[]> {
    const comments = await this.comments.list(req.user.orgId, assetId);
    return comments.map(toDto);
  }
}
