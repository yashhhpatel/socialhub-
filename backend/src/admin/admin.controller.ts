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
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminAuditService } from './admin-audit.service';
import { AdminBillingService } from './admin-billing.service';
import { AdminComplianceService } from './admin-compliance.service';
import { AdminSystemService } from './admin-system.service';
import { AdminOrganizationsService } from './admin-organizations.service';
import { AdminOverviewService } from './admin-overview.service';
import { AdminPublishingService } from './admin-publishing.service';
import { AdminSocialAccountsService } from './admin-social-accounts.service';
import { AdminUsersService } from './admin-users.service';
import {
  AdminOrgDetailDto,
  AdminOrgListDto,
} from './dto/admin-organizations.dto';
import { AdminAuditListDto } from './dto/admin-audit.dto';
import { AdminBillingDto } from './dto/admin-billing.dto';
import {
  AdminHealthDto,
  AdminQueueStatDto,
  AdminRecentErrorDto,
} from './dto/admin-system.dto';
import {
  AdminDataDeletionListDto,
  AdminOrgStatusDto,
} from './dto/admin-compliance.dto';
import { AdminPublishJobListDto } from './dto/admin-publishing.dto';
import { AdminOverviewDto } from './dto/admin-overview.dto';
import {
  AdminRefreshResultDto,
  AdminSocialAccountListDto,
} from './dto/admin-social-accounts.dto';
import {
  AdminUserDetailDto,
  AdminUserListDto,
} from './dto/admin-users.dto';
import { PlatformAdminGuard } from './guards/platform-admin.guard';

interface AuthedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

/**
 * Platform admin API (Phase 21). Every route here is gated by
 * JwtAuthGuard + PlatformAdminGuard, so only platform admins reach it. Reads
 * are cross-tenant; secrets are never selected. Feature endpoints are added by
 * later milestones — this base carries the identity check.
 */
@UseGuards(JwtAuthGuard, PlatformAdminGuard)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly overviewService: AdminOverviewService,
    private readonly organizationsService: AdminOrganizationsService,
    private readonly usersService: AdminUsersService,
    private readonly socialAccountsService: AdminSocialAccountsService,
    private readonly billingService: AdminBillingService,
    private readonly publishingService: AdminPublishingService,
    private readonly auditService: AdminAuditService,
    private readonly complianceService: AdminComplianceService,
    private readonly systemService: AdminSystemService,
  ) {}

  /** Confirms the caller is a platform admin (drives the admin shell gate). */
  @Get('me')
  me(@Req() req: AuthedRequest): { userId: string; email: string; isPlatformAdmin: true } {
    return { userId: req.user.userId, email: req.user.email, isPlatformAdmin: true };
  }

  /** Cross-tenant platform KPIs for the Overview dashboard (21.2). */
  @Get('overview')
  overview(): Promise<AdminOverviewDto> {
    return this.overviewService.overview();
  }

  /** Paginated, searchable organization list (21.3). */
  @Get('organizations')
  listOrganizations(
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ): Promise<AdminOrgListDto> {
    return this.organizationsService.list({
      search,
      page: page ? Number(page) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  /** Full detail for one organization (21.3). */
  @Get('organizations/:id')
  organizationDetail(@Param('id') id: string): Promise<AdminOrgDetailDto> {
    return this.organizationsService.detail(id);
  }

  // --- Users (21.4) ---

  /** Paginated, searchable user list (by email). */
  @Get('users')
  listUsers(
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ): Promise<AdminUserListDto> {
    return this.usersService.list({
      search,
      page: page ? Number(page) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  /** Full detail for one user. */
  @Get('users/:id')
  userDetail(@Param('id') id: string): Promise<AdminUserDetailDto> {
    return this.usersService.detail(id);
  }

  /** Re-send the email-verification link to a user (safe). */
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('users/:id/resend-verification')
  resendVerification(@Param('id') id: string): Promise<void> {
    return this.usersService.resendVerification(id);
  }

  /** Send a password-reset link to a user (the admin never sets the password). */
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('users/:id/force-password-reset')
  forcePasswordReset(@Param('id') id: string): Promise<void> {
    return this.usersService.forcePasswordReset(id);
  }

  // --- Social accounts (21.5) ---

  /** Cross-tenant social-account health (filter by status/platform). */
  @Get('social-accounts')
  listSocialAccounts(
    @Query('status') status?: string,
    @Query('platform') platform?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ): Promise<AdminSocialAccountListDto> {
    return this.socialAccountsService.list({
      status,
      platform,
      page: page ? Number(page) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  /** Force a token refresh; reports whether the account now needs reconnection. */
  @HttpCode(HttpStatus.OK)
  @Post('social-accounts/:id/refresh')
  refreshSocialAccount(@Param('id') id: string): Promise<AdminRefreshResultDto> {
    return this.socialAccountsService.refresh(id);
  }

  /** Disconnect (delete) a social account. */
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('social-accounts/:id/disconnect')
  disconnectSocialAccount(@Param('id') id: string): Promise<void> {
    return this.socialAccountsService.disconnect(id);
  }

  // --- Billing & revenue (21.6) ---

  /** Cross-tenant billing overview (subscriptions, dunning, revenue, invoices). */
  @Get('billing')
  billing(): Promise<AdminBillingDto> {
    return this.billingService.overview();
  }

  // --- Content & publishing (21.7) ---

  /** Cross-tenant publish jobs (filter by status; failed = the triage queue). */
  @Get('publish-jobs')
  listPublishJobs(
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ): Promise<AdminPublishJobListDto> {
    return this.publishingService.list({
      status,
      page: page ? Number(page) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  /** Re-enqueue a job for another attempt (never a published job). */
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('publish-jobs/:id/retry')
  retryPublishJob(@Param('id') id: string): Promise<void> {
    return this.publishingService.retry(id);
  }

  /** Cancel a job (not a published one). */
  @HttpCode(HttpStatus.NO_CONTENT)
  @Post('publish-jobs/:id/cancel')
  cancelPublishJob(@Param('id') id: string): Promise<void> {
    return this.publishingService.cancel(id);
  }

  // --- Audit log (21.8) ---

  /** Cross-org audit trail (optional org/actor/method filters). */
  @Get('audit-logs')
  auditLogs(
    @Query('orgId') orgId?: string,
    @Query('actorEmail') actorEmail?: string,
    @Query('method') method?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ): Promise<AdminAuditListDto> {
    return this.auditService.list({
      orgId,
      actorEmail,
      method,
      page: page ? Number(page) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  // --- Compliance & suspension (21.9) ---

  /** Meta data-deletion request queue. */
  @Get('data-deletion-requests')
  dataDeletionRequests(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ): Promise<AdminDataDeletionListDto> {
    return this.complianceService.dataDeletionRequests({
      page: page ? Number(page) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  /** Suspend a workspace — its members can no longer obtain a session. */
  @HttpCode(HttpStatus.OK)
  @Post('organizations/:id/suspend')
  suspendOrg(@Param('id') id: string): Promise<AdminOrgStatusDto> {
    return this.complianceService.suspendOrg(id);
  }

  /** Reactivate a suspended workspace. */
  @HttpCode(HttpStatus.OK)
  @Post('organizations/:id/reactivate')
  reactivateOrg(@Param('id') id: string): Promise<AdminOrgStatusDto> {
    return this.complianceService.reactivateOrg(id);
  }

  // --- System & monitoring (21.10) ---

  /** Deep health: probes Postgres + Redis, not just uptime. */
  @Get('system/health')
  systemHealth(): Promise<AdminHealthDto> {
    return this.systemService.health();
  }

  /** BullMQ queue job counts (publish queues + token-refresh sweep). */
  @Get('system/queues')
  systemQueues(): Promise<AdminQueueStatDto[]> {
    return this.systemService.queues_();
  }

  /** Recent 4xx/5xx across all tenants (from the audit trail). */
  @Get('system/errors')
  systemErrors(): Promise<AdminRecentErrorDto[]> {
    return this.systemService.recentErrors();
  }
}
