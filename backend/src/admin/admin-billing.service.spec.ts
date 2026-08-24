import { PrismaService } from '../prisma/prisma.service';
import { AdminBillingService } from './admin-billing.service';

describe('AdminBillingService', () => {
  let service: AdminBillingService;
  let prisma: {
    subscription: { groupBy: jest.Mock; findMany: jest.Mock };
    invoice: { aggregate: jest.Mock; findMany: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      subscription: { groupBy: jest.fn(), findMany: jest.fn() },
      invoice: { aggregate: jest.fn(), findMany: jest.fn() },
    };
    service = new AdminBillingService(prisma as unknown as PrismaService);
  });

  it('summarizes subscriptions, revenue, dunning and invoices (no secrets)', async () => {
    prisma.subscription.groupBy
      .mockResolvedValueOnce([{ planTier: 'pro', _count: { _all: 2 } }]) // activeByTier
      .mockResolvedValueOnce([
        { status: 'active', _count: { _all: 2 } },
        { status: 'pastDue', _count: { _all: 1 } },
      ]); // byStatus
    prisma.invoice.aggregate
      .mockResolvedValueOnce({ _sum: { amountPaid: 12345 } }) // all-time
      .mockResolvedValueOnce({ _sum: { amountPaid: 2000 } }); // 30d
    prisma.subscription.findMany.mockResolvedValue([
      {
        orgId: 'o1',
        planTier: 'pro',
        status: 'pastDue',
        currentPeriodEnd: new Date(0),
        organization: { name: 'Acme' },
      },
    ]);
    prisma.invoice.findMany.mockResolvedValue([
      {
        id: 'i1',
        orgId: 'o1',
        amountDue: 5000,
        amountPaid: 5000,
        currency: 'usd',
        status: 'paid',
        hostedInvoiceUrl: 'https://stripe/i1',
        createdAt: new Date(0),
        organization: { name: 'Acme' },
      },
    ]);

    const b = await service.overview();

    expect(b.activeByTier).toEqual([{ key: 'pro', count: 2 }]);
    expect(b.subscriptionsByStatus).toContainEqual({ key: 'pastDue', count: 1 });
    expect(b.revenuePaidAllTime).toBe(12345);
    expect(b.revenuePaid30d).toBe(2000);
    expect(b.currency).toBe('usd');
    expect(b.pastDue[0].orgName).toBe('Acme');
    expect(b.recentInvoices[0].hostedInvoiceUrl).toBe('https://stripe/i1');
    // No Stripe keys / secret ids beyond the hosted link.
    expect(JSON.stringify(b)).not.toMatch(/sk_live|sk_test|secret/i);
  });

  it('defaults revenue to 0 and currency to usd with no invoices', async () => {
    prisma.subscription.groupBy.mockResolvedValue([]);
    prisma.invoice.aggregate.mockResolvedValue({ _sum: { amountPaid: null } });
    prisma.subscription.findMany.mockResolvedValue([]);
    prisma.invoice.findMany.mockResolvedValue([]);

    const b = await service.overview();
    expect(b.revenuePaidAllTime).toBe(0);
    expect(b.currency).toBe('usd');
    expect(b.pastDue).toEqual([]);
  });
});
