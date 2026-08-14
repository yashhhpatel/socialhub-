import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { ListJobsDto } from './dto/list-jobs.dto';
import {
  PublishJobDto,
  PublishJobSummaryDto,
  PublishNowResponseDto,
} from './dto/publish-job.dto';
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
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
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
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
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

  /**
   * The org's publish jobs for the scheduler/calendar view (Milestone 7.4).
   * Optional `?status=` filter. Declared before `jobs/:id` so the literal
   * path wins over the parameter route.
   */
  @UseGuards(JwtAuthGuard)
  @Get('jobs')
  async listJobs(
    @Req() req: AuthenticatedRequest,
    @Query() query: ListJobsDto,
  ): Promise<PublishJobSummaryDto[]> {
    const jobs = await this.publishingService.listJobs(
      req.user.orgId,
      query.status,
    );
    return jobs.map((job) => ({
      id: job.id,
      platform: job.socialAccount.platform,
      status: job.status,
      scheduledAt: job.scheduledAt,
      attemptCount: job.attemptCount,
      lastError: job.lastError,
      externalPostId: job.externalPostId,
      createdAt: job.createdAt,
    }));
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

  /** Cancels a still-scheduled post (Milestone 7.4). */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
  @Delete('jobs/:id')
  async cancelJob(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<PublishJobDto> {
    const job = await this.publishingService.cancelScheduled(id, req.user.orgId);
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
