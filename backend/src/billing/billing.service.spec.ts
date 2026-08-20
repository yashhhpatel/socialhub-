import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PlanTier, SubscriptionStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { BillingService } from './billing.service';
import { PlanLimitsService } from './plan-limits.service';
import { StripeService } from './stripe.service';

describe('BillingService', () => {
  let service: BillingService;
  let prisma: any;
  let stripe: any;
  let planLimits: any;
  let config: any;
  let txOps: unknown[];

  beforeEach(() => {
    txOps = [];
    prisma = {
      organization: { findUnique: jest.fn(), update: jest.fn((a) => a) },
      subscription: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        upsert: jest.fn((a) => a),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      invoice: { findMany: jest.fn().mockResolvedValue([]), upsert: jest.fn() },
      // Records the ops passed in the array form.
      $transaction: jest.fn(async (ops: unknown[]) => {
        txOps.push(...ops);
        return ops;
      }),
    };
    stripe = {
      enabled: true,
      createCustomer: jest.fn().mockResolvedValue('cus_1'),
      createCheckoutSession: jest.fn().mockResolvedValue('https://checkout/x'),
      createPortalSession: jest.fn().mockResolvedValue('https://portal/x'),
      getSubscription: jest.fn(),
    };
    planLimits = { usage: jest.fn().mockResolvedValue({ socialAccounts: 0, teamMembers: 1, aiCreditsUsed: 0 }) };
    config = {
      get: jest.fn((k: string) => {
        const env: Record<string, string> = {
          STRIPE_PRICE_PRO: 'price_pro',
          FRONTEND_URL: 'http://localhost:8080',
        };
        return env[k];
      }),
    };
    service = new BillingService(
      prisma as PrismaService,
      stripe as unknown as StripeService,
      planLimits as PlanLimitsService,
      config as ConfigService,
    );
  });

  describe('startCheckout', () => {
    it('throws 503 when Stripe is not configured', async () => {
      stripe.enabled = false;
      await expect(
        service.startCheckout({ orgId: 'o1', tier: PlanTier.pro, userEmail: 'a@b.c' }),
      ).rejects.toBeInstanceOf(ServiceUnavailableException);
    });

    it('creates a customer + checkout session for a purchasable tier', async () => {
      prisma.subscription.findUnique.mockResolvedValue(null); // no customer yet
      prisma.subscription.upsert.mockResolvedValue({});
      const result = await service.startCheckout({
        orgId: 'o1',
        tier: PlanTier.pro,
        userEmail: 'a@b.c',
      });
      expect(stripe.createCustomer).toHaveBeenCalled();
      expect(stripe.createCheckoutSession).toHaveBeenCalledWith(
        expect.objectContaining({ priceId: 'price_pro', customerId: 'cus_1', orgId: 'o1' }),
      );
      expect(result.url).toBe('https://checkout/x');
    });

    it('reuses an existing Stripe customer', async () => {
      prisma.subscription.findUnique.mockResolvedValue({ stripeCustomerId: 'cus_existing' });
      await service.startCheckout({ orgId: 'o1', tier: PlanTier.pro, userEmail: 'a@b.c' });
      expect(stripe.createCustomer).not.toHaveBeenCalled();
      expect(stripe.createCheckoutSession).toHaveBeenCalledWith(
        expect.objectContaining({ customerId: 'cus_existing' }),
      );
    });
  });

  describe('handleWebhook', () => {
    it('syncs the org plan tier from a subscription.updated event', async () => {
      prisma.subscription.upsert.mockResolvedValue({});
      prisma.organization.update.mockResolvedValue({});

      await service.handleWebhook({
        type: 'customer.subscription.updated',
        data: {
          object: {
            id: 'sub_1',
            customer: 'cus_1',
            status: 'active',
            metadata: { orgId: 'o1' },
            cancel_at_period_end: false,
            current_period_end: 1800000000,
            items: { data: [{ price: { id: 'price_pro' } }] },
          },
        },
      });

      // Upsert wrote the pro tier + active status; org tier updated to pro.
      const subUpsert = prisma.subscription.upsert.mock.calls[0][0];
      expect(subUpsert.where).toEqual({ orgId: 'o1' });
      expect(subUpsert.create.planTier).toBe(PlanTier.pro);
      expect(subUpsert.create.status).toBe(SubscriptionStatus.active);
      const orgUpdate = prisma.organization.update.mock.calls[0][0];
      expect(orgUpdate).toEqual({ where: { id: 'o1' }, data: { planTier: PlanTier.pro } });
    });

    it('drops the org to free on subscription.deleted', async () => {
      await service.handleWebhook({
        type: 'customer.subscription.deleted',
        data: { object: { id: 'sub_1', customer: 'cus_1', metadata: { orgId: 'o1' } } },
      });
      const subUpsert = prisma.subscription.upsert.mock.calls[0][0];
      expect(subUpsert.create.planTier).toBe(PlanTier.free);
      expect(subUpsert.create.status).toBe(SubscriptionStatus.canceled);
    });

    it('records the invoice and marks the sub past-due on payment_failed (dunning)', async () => {
      await service.handleWebhook({
        type: 'invoice.payment_failed',
        data: {
          object: {
            id: 'in_1',
            customer: 'cus_1',
            metadata: { orgId: 'o1' },
            amount_due: 2900,
            currency: 'usd',
            status: 'open',
          },
        },
      });
      expect(prisma.invoice.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ where: { stripeInvoiceId: 'in_1' } }),
      );
      expect(prisma.subscription.updateMany).toHaveBeenCalledWith({
        where: { orgId: 'o1' },
        data: { status: SubscriptionStatus.pastDue },
      });
    });

    it('ignores unhandled event types without throwing', async () => {
      await expect(
        service.handleWebhook({ type: 'customer.created', data: { object: {} } }),
      ).resolves.toBeUndefined();
    });
  });

  describe('getOverview', () => {
    it('returns plan, limits, usage and invoices', async () => {
      prisma.organization.findUnique.mockResolvedValue({ planTier: PlanTier.starter });
      prisma.subscription.findUnique.mockResolvedValue({
        status: SubscriptionStatus.active,
        currentPeriodEnd: new Date(),
        cancelAtPeriodEnd: false,
        stripeCustomerId: 'cus_1',
      });
      const overview = await service.getOverview('o1');
      expect(overview.planTier).toBe(PlanTier.starter);
      expect(overview.limits.maxSocialAccounts).toBe(5);
      expect(overview.usage).toEqual({ socialAccounts: 0, teamMembers: 1, aiCreditsUsed: 0 });
      expect(overview.billingConfigured).toBe(true);
    });
  });
});
