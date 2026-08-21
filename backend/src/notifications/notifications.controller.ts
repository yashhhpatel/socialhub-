import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Notification } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

interface AuthedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  /// The signed-in user's recent notifications (newest first).
  @Get()
  list(
    @Req() req: AuthedRequest,
    @Query('limit') limit?: string,
  ): Promise<Notification[]> {
    const n = limit ? Math.min(Math.max(parseInt(limit, 10) || 30, 1), 100) : 30;
    return this.notifications.listForUser(req.user.userId, n);
  }

  /// Unread count for the nav badge.
  @Get('unread-count')
  async unreadCount(@Req() req: AuthedRequest): Promise<{ count: number }> {
    return { count: await this.notifications.unreadCount(req.user.userId) };
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Post(':id/read')
  async markRead(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    await this.notifications.markRead(id, req.user.userId);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('read-all')
  async markAllRead(@Req() req: AuthedRequest): Promise<void> {
    await this.notifications.markAllRead(req.user.userId);
  }
}
