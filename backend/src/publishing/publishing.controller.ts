import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PublishJobDto, PublishNowResponseDto } from './dto/publish-job.dto';
import { PublishNowDto } from './dto/publish-now.dto';
import { PublishingService } from './publishing.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@Controller('publish')
export class PublishingController {
  constructor(private readonly publishingService: PublishingService) {}

  /**
   * Publishes a rendition to a connected account (Milestone 4.2).
   *
   * 202 per the REST design doc. Publishing is synchronous today, so the
   * job is already `published` by the time this returns — but Phase 7
   * moves it onto a queue, and keeping the async-shaped contract now
   * means the frontend written against it needs no change then.
   */
  @UseGuards(JwtAuthGuard)
  @Post('now')
  @HttpCode(HttpStatus.ACCEPTED)
  async publishNow(
    @Req() req: AuthenticatedRequest,
    @Body() dto: PublishNowDto,
  ): Promise<PublishNowResponseDto> {
    const job = await this.publishingService.publishNow(
      req.user.orgId,
      dto.variantId,
      dto.socialAccountId,
    );
    return { jobId: job.id, status: job.status };
  }

  @UseGuards(JwtAuthGuard)
  @Get('jobs/:id')
  async getJob(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<PublishJobDto> {
    const job = await this.publishingService.findJobScoped(id, req.user.orgId);
    return {
      id: job.id,
      status: job.status,
      attemptCount: job.attemptCount,
      scheduledAt: job.scheduledAt,
      lastError: job.lastError,
      externalPostId: job.externalPostId,
    };
  }
}
