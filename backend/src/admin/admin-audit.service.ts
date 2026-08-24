import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { AdminAuditListDto } from './dto/admin-audit.dto';

const MAX_LIMIT = 100;

/**
 * Cross-org audit-log viewer (Phase 21.8). The audit trail already records every
 * authenticated mutation (global AuditLogInterceptor); this just queries it
 * WITHOUT the per-org filter the tenant endpoint applies, with optional
 * filters. Read-only.
 */
@Injectable()
export class AdminAuditService {
  constructor(private readonly prisma: PrismaService) {}

  async list(params: {
    orgId?: string;
    actorEmail?: string;
    method?: string;
    page?: number;
    limit?: number;
  }): Promise<AdminAuditListDto> {
    const page = Math.max(1, params.page ?? 1);
    const limit = Math.min(MAX_LIMIT, Math.max(1, params.limit ?? 25));

    const where: Prisma.AuditLogWhereInput = {};
    if (params.orgId?.trim()) where.orgId = params.orgId.trim();
    if (params.actorEmail?.trim()) {
      where.actorEmail = {
        contains: params.actorEmail.trim().toLowerCase(),
        mode: 'insensitive',
      };
    }
    if (params.method?.trim()) where.method = params.method.trim().toUpperCase();

    const [total, rows] = await Promise.all([
      this.prisma.auditLog.count({ where }),
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          orgId: true,
          actorEmail: true,
          method: true,
          path: true,
          targetId: true,
          statusCode: true,
          createdAt: true,
        },
      }),
    ]);

    return { total, page, limit, data: rows };
  }
}
