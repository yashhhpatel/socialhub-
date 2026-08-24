import { Injectable } from '@nestjs/common';
import { SubscriptionStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { AdminBillingDto } from './dto/admin-billing.dto';

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Cross-tenant billing/revenue overview (Phase 21.6). Derived from the existing
 * Subscription/Invoice tables; no Stripe keys or card data ever leave the API —
 * invoices carry only a hosted link. Amounts are minor units (cents).
 */
@Injectable()
export class AdminBillingService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(): Promise<AdminBillingDto> {
    const since = new Date(Date.now() - THIRTY_DAYS_MS);

    const [
      activeByTier,
      byStatus,
      paidAllTime,
      paid30d,
      pastDueSubs,
      invoices,
    ] = await Promise.all([
      this.prisma.subscription.groupBy({
        by: ['planTier'],
        where: { status: SubscriptionStatus.active },
        _count: { _all: true },
      }),
      this.prisma.subscription.groupBy({
        by: ['status'],
        _count: { _all: true },
      }),
      this.prisma.invoice.aggregate({ _sum: { amountPaid: true } }),
      this.prisma.invoice.aggregate({
        _sum: { amountPaid: true },
        where: { createdAt: { gte: since } },
      }),
      this.prisma.subscription.findMany({
        where: { status: SubscriptionStatus.pastDue },
        select: {
          orgId: true,
          planTier: true,
          status: true,
          currentPeriodEnd: true,
          organization: { select: { name: true } },
        },
      }),
      this.prisma.invoice.findMany({
        orderBy: { createdAt: 'desc' },
        take: 20,
        select: {
          id: true,
          orgId: true,
          amountDue: true,
          amountPaid: true,
          currency: true,
          status: true,
          hostedInvoiceUrl: true,
          createdAt: true,
          organization: { select: { name: true } },
        },
      }),
    ]);

    return {
      activeByTier: activeByTier.map((g) => ({
        key: g.planTier,
        count: g._count._all,
      })),
      subscriptionsByStatus: byStatus.map((g) => ({
        key: g.status,
        count: g._count._all,
      })),
      revenuePaidAllTime: paidAllTime._sum.amountPaid ?? 0,
      revenuePaid30d: paid30d._sum.amountPaid ?? 0,
      currency: invoices[0]?.currency ?? 'usd',
      pastDue: pastDueSubs.map((s) => ({
        orgId: s.orgId,
        orgName: s.organization.name,
        planTier: s.planTier,
        status: s.status,
        currentPeriodEnd: s.currentPeriodEnd,
      })),
      recentInvoices: invoices.map((i) => ({
        id: i.id,
        orgId: i.orgId,
        orgName: i.organization.name,
        amountDue: i.amountDue,
        amountPaid: i.amountPaid,
        currency: i.currency,
        status: i.status,
        hostedInvoiceUrl: i.hostedInvoiceUrl,
        createdAt: i.createdAt,
      })),
    };
  }
}
