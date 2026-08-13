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
import { SchedulePublishDto } from './dto/schedule-publish.dto';
import { PublishingService } from './publishing.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@Controller('publish')
export class PublishingController {
  constructor(private readonly publishingService: PublishingService) {}

  /**
   * Publishes a rendition to a connected account (Milestone 4.2, queued in
   * 7.2). 202 per the REST design doc: the request validates and enqueues,
   * returning a `queued` job the caller polls via GET /publish/jobs/:id.
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
      dto.caption,
    );
    return { jobId: job.id, status: job.status };
  }

  /**
   * Schedules a rendition to publish at a future time (Milestone 7.3).
   *
   * 202, same shape as /publish/now: returns a `scheduled` job to poll. The
   * cron enqueues it when it comes due, at which point its status walks the
   * usual queued -> processing -> published|failed path.
   */
  @UseGuards(JwtAuthGuard)
  @Post('schedule')
  @HttpCode(HttpStatus.ACCEPTED)
  async schedule(
    @Req() req: AuthenticatedRequest,
    @Body() dto: SchedulePublishDto,
  ): Promise<PublishNowResponseDto> {
    const job = await this.publishingService.schedule(
      req.user.orgId,
      dto.variantId,
      dto.socialAccountId,
      new Date(dto.scheduledAt),
      dto.caption,
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
