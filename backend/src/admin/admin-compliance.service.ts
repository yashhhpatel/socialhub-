import { Injectable, NotFoundException } from '@nestjs/common';
import { OrgStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  AdminDataDeletionListDto,
  AdminOrgStatusDto,
} from './dto/admin-compliance.dto';

const MAX_LIMIT = 100;

/**
 * Compliance queue + tenant suspension for the admin panel (Phase 21.9).
 * Data-deletion requests come from the existing Meta callback table; suspension
 * flips Organization.status (enforced at login by AuthService).
 */
@Injectable()
export class AdminComplianceService {
  constructor(private readonly prisma: PrismaService) {}

  async dataDeletionRequests(params: {
    page?: number;
    limit?: number;
  }): Promise<AdminDataDeletionListDto> {
    const page = Math.max(1, params.page ?? 1);
    const limit = Math.min(MAX_LIMIT, Math.max(1, params.limit ?? 25));

    const [total, rows] = await Promise.all([
      this.prisma.dataDeletionRequest.count(),
      this.prisma.dataDeletionRequest.findMany({
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          platform: true,
          confirmationCode: true,
          status: true,
          createdAt: true,
        },
      }),
    ]);

    return { total, page, limit, data: rows };
  }

  suspendOrg(orgId: string): Promise<AdminOrgStatusDto> {
    return this.setOrgStatus(orgId, OrgStatus.suspended);
  }

  reactivateOrg(orgId: string): Promise<AdminOrgStatusDto> {
    return this.setOrgStatus(orgId, OrgStatus.active);
  }

  private async setOrgStatus(
    orgId: string,
    status: OrgStatus,
  ): Promise<AdminOrgStatusDto> {
    const exists = await this.prisma.organization.findUnique({
      where: { id: orgId },
      select: { id: true },
    });
    if (!exists) throw new NotFoundException('Organization not found.');

    const org = await this.prisma.organization.update({
      where: { id: orgId },
      data: {
        status,
        suspendedAt: status === OrgStatus.suspended ? new Date() : null,
      },
      select: { id: true, status: true, suspendedAt: true },
    });
    return { orgId: org.id, status: org.status, suspendedAt: org.suspendedAt };
  }
}
