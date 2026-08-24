import { Injectable } from '@nestjs/common';
import { PublishJobStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { PublishingService } from '../publishing/publishing.service';
import { AdminPublishJobListDto } from './dto/admin-publishing.dto';

const MAX_LIMIT = 100;

/**
 * Cross-tenant publishing management for the admin panel (Phase 21.7). Reads the
 * publish pipeline across orgs; retry/cancel delegate to PublishingService so
 * the queue semantics live in one place.
 */
@Injectable()
export class AdminPublishingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly publishing: PublishingService,
  ) {}

  async list(params: {
    status?: string;
    page?: number;
    limit?: number;
  }): Promise<AdminPublishJobListDto> {
    const page = Math.max(1, params.page ?? 1);
    const limit = Math.min(MAX_LIMIT, Math.max(1, params.limit ?? 20));

    const where =
      params.status && isStatus(params.status)
        ? { status: params.status }
        : {};

    const [total, rows] = await Promise.all([
      this.prisma.publishJob.count({ where }),
      this.prisma.publishJob.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          status: true,
          attemptCount: true,
          lastError: true,
          scheduledAt: true,
          externalPostId: true,
          createdAt: true,
          socialAccount: {
            select: {
              platform: true,
              externalAccountId: true,
              orgId: true,
              organization: { select: { name: true } },
            },
          },
        },
      }),
    ]);

    return {
      total,
      page,
      limit,
      data: rows.map((j) => ({
        id: j.id,
        orgId: j.socialAccount.orgId,
        orgName: j.socialAccount.organization.name,
        platform: j.socialAccount.platform,
        externalAccountId: j.socialAccount.externalAccountId,
        status: j.status,
        attemptCount: j.attemptCount,
        lastError: j.lastError,
        scheduledAt: j.scheduledAt,
        externalPostId: j.externalPostId,
        createdAt: j.createdAt,
      })),
    };
  }

  retry(id: string): Promise<void> {
    return this.publishing.requeueJob(id);
  }

  cancel(id: string): Promise<void> {
    return this.publishing.cancelJob(id);
  }
}

function isStatus(value: string): value is PublishJobStatus {
  return (Object.values(PublishJobStatus) as string[]).includes(value);
}
