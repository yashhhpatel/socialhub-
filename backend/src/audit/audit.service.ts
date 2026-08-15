import { Injectable } from '@nestjs/common';
import { AuditLog } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { ListAuditLogsDto } from './dto/list-audit-logs.dto';

/**
 * Reads the org's audit trail (Milestone 15.2). Always org-scoped — an org
 * only ever sees its own actions — with optional method/actor/date filters
 * for the audit table's UI. Newest first.
 */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  list(orgId: string, query: ListAuditLogsDto): Promise<AuditLog[]> {
    const createdAt =
      query.from || query.to
        ? {
            ...(query.from ? { gte: new Date(query.from) } : {}),
            ...(query.to ? { lte: new Date(query.to) } : {}),
          }
        : undefined;

    return this.prisma.auditLog.findMany({
      where: {
        orgId,
        ...(query.method ? { method: query.method } : {}),
        ...(query.actorEmail ? { actorEmail: query.actorEmail } : {}),
        ...(createdAt ? { createdAt } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: query.limit ?? 100,
    });
  }
}
