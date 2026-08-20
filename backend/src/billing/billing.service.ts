import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PlanTier, SubscriptionStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { PlanLimitsService } from './plan-limits.service';
import {
  PLAN_LIMITS,
  PURCHASABLE_TIERS,
  stripePriceEnvKey,
} from './plan-config';
import { StripeService } from './stripe.service';

/// Orchestrates billing (Phase 18): checkout + portal sessions, the Stripe
/// webhook that keeps the local Subscription/Invoice mirror (and
/// Organization.planTier) in sync, dunning on failed payments, and the billing
/// overview the UI renders.
///
/// Live charging needs the merchant's Stripe keys at runtime (STRIPE_SECRET_KEY
/// + price ids); without them the mutating flows surface a clean "not
/// configured" 503 rather than failing opaquely — the same optional-at-boot
/// pattern the OAuth adapters and AI gateway use. All state-changing logic is
/// otherwise fully implemented and unit-tested against a mocked Stripe.
@Injectable()
export class BillingService {
  private readonly logger = new Logger(BillingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly stripe: StripeService,
    private readonly planLimits: PlanLimitsService,
    private readonly config: ConfigService,
  ) {}

  /// Billing state for the org's billing page.
  async getOverview(orgId: string) {
    const [org, subscription, usage, invoices] = await Promise.all([
      this.prisma.organization.findUnique({
        where: { id: orgId },
        select: { planTier: true },
      }),
      this.prisma.subscription.findUnique({ where: { orgId } }),
      this.planLimits.usage(orgId),
      this.prisma.invoice.findMany({
        where: { orgId },
        orderBy: { createdAt: 'desc' },
        take: 12,
      }),
    ]);

    const planTier = org?.planTier ?? PlanTier.free;
    return {
      planTier,
      status: subscription?.status ?? SubscriptionStatus.none,
      currentPeriodEnd: subscription?.currentPeriodEnd ?? null,
      cancelAtPeriodEnd: subscription?.cancelAtPeriodEnd ?? false,
      hasBillingAccount: !!subscription?.stripeCustomerId,
      billingConfigured: this.stripe.enabled,
      limits: PLAN_LIMITS[planTier],
      usage,
      invoices: invoices.map((i) => ({
        id: i.id,
        amountDue: i.amountDue,
        amountPaid: i.amountPaid,
        currency: i.currency,
        status: i.status,
        hostedInvoiceUrl: i.hostedInvoiceUrl,
        createdAt: i.createdAt,
      })),
    };
  }

  /// Starts a Stripe Checkout for the given tier; returns the hosted URL.
  async startCheckout(params: {
    orgId: string;
    tier: PlanTier;
    userEmail: string;
  }): Promise<{ url: string }> {
    this.assertConfigured();
    if (!PURCHASABLE_TIERS.includes(params.tier)) {
      throw new BadRequestException(`'${params.tier}' is not a purchasable plan.`);
    }
    const priceId = this.config.get<string>(stripePriceEnvKey(params.tier));
    if (!priceId) {
      throw new ServiceUnavailableException(
        `The ${params.tier} plan isn't available for purchase yet ` +
          `(no Stripe price configured).`,
      );
    }

    const customerId = await this.ensureCustomer(params.orgId, params.userEmail);
    const appUrl = this.frontendUrl();
    const url = await this.stripe.createCheckoutSession({
      customerId,
      priceId,
      orgId: params.orgId,
      successUrl: `${appUrl}/#/billing?checkout=success`,
      cancelUrl: `${appUrl}/#/billing?checkout=cancelled`,
    });
    return { url };
  }

  /// Starts a Stripe Billing Portal session; returns its URL.
  async startPortal(orgId: string): Promise<{ url: string }> {
    this.assertConfigured();
    const subscription = await this.prisma.subscription.findUnique({
      where: { orgId },
    });
    if (!subscription?.stripeCustomerId) {
      throw new BadRequestException(
        'No billing account yet — start a subscription first.',
      );
    }
    const url = await this.stripe.createPortalSession({
      customerId: subscription.stripeCustomerId,
      returnUrl: `${this.frontendUrl()}/#/billing`,
    });
    return { url };
  }

  /// Applies a verified Stripe webhook event to the local mirror. Unhandled
  /// event types are ignored (returns without error) so Stripe still gets a 200.
  async handleWebhook(event: Record<string, unknown>): Promise<void> {
    const type = event.type as string;
    const object = (event.data as { object?: Record<string, unknown> })?.object ?? {};

    switch (type) {
      case 'checkout.session.completed': {
        const subId = object.subscription as string | undefined;
        if (subId) {
          const sub = await this.stripe.getSubscription(subId);
          await this.syncSubscription(sub);
        }
        break;
      }
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        await this.syncSubscription(object, type === 'customer.subscription.deleted');
        break;
      case 'invoice.paid':
      case 'invoice.payment_succeeded':
        await this.recordInvoice(object);
        break;
      case 'invoice.payment_failed':
        await this.recordInvoice(object);
        await this.markPastDue(object);
        break;
      default:
        this.logger.debug(`Ignoring unhandled Stripe event: ${type}`);
    }
  }

  /// Upserts the local Subscription from a Stripe subscription object and syncs
  /// Organization.planTier. `deleted` forces the org back to the free plan.
  private async syncSubscription(
    stripeSub: Record<string, unknown>,
    deleted = false,
  ): Promise<void> {
    const orgId = await this.resolveOrgId(stripeSub);
    if (!orgId) {
      this.logger.warn('Stripe subscription webhook had no resolvable orgId');
      return;
    }

    const tier = deleted ? PlanTier.free : this.tierFromSubscription(stripeSub);
    const status = deleted
      ? SubscriptionStatus.canceled
      : this.mapStatus(stripeSub.status as string);
    const currentPeriodEnd =
      typeof stripeSub.current_period_end === 'number'
        ? new Date((stripeSub.current_period_end as number) * 1000)
        : null;
    const cancelAtPeriodEnd = stripeSub.cancel_at_period_end === true;
    const customerId = stripeSub.customer as string | undefined;
    const subscriptionId = stripeSub.id as string | undefined;

    await this.prisma.$transaction([
      this.prisma.subscription.upsert({
        where: { orgId },
        create: {
          orgId,
          stripeCustomerId: customerId,
          stripeSubscriptionId: subscriptionId,
          planTier: tier,
          status,
          currentPeriodEnd,
          cancelAtPeriodEnd,
        },
        update: {
          stripeCustomerId: customerId,
          stripeSubscriptionId: subscriptionId,
          planTier: tier,
          status,
          currentPeriodEnd,
          cancelAtPeriodEnd,
        },
      }),
      this.prisma.organization.update({
        where: { id: orgId },
        // A canceled/free subscription drops the org to the free plan.
        data: { planTier: tier },
      }),
    ]);
  }

  private async recordInvoice(invoice: Record<string, unknown>): Promise<void> {
    const orgId = await this.resolveOrgId(invoice);
    const stripeInvoiceId = invoice.id as string | undefined;
    if (!orgId || !stripeInvoiceId) return;

    const period = (invoice.period_start as number | undefined) ?? undefined;
    const periodEnd = (invoice.period_end as number | undefined) ?? undefined;
    const data = {
      orgId,
      amountDue: (invoice.amount_due as number | undefined) ?? 0,
      amountPaid: (invoice.amount_paid as number | undefined) ?? 0,
      currency: (invoice.currency as string | undefined) ?? 'usd',
      status: (invoice.status as string | undefined) ?? 'open',
      hostedInvoiceUrl: (invoice.hosted_invoice_url as string | undefined) ?? null,
      periodStart: period ? new Date(period * 1000) : null,
      periodEnd: periodEnd ? new Date(periodEnd * 1000) : null,
    };
    await this.prisma.invoice.upsert({
      where: { stripeInvoiceId },
      create: { stripeInvoiceId, ...data },
      update: data,
    });
  }

  /// Dunning: a failed payment moves the subscription to pastDue so the UI can
  /// prompt the user to update their card (access isn't cut immediately —
  /// Stripe retries per the merchant's dunning settings).
  private async markPastDue(invoice: Record<string, unknown>): Promise<void> {
    const orgId = await this.resolveOrgId(invoice);
    if (!orgId) return;
    await this.prisma.subscription.updateMany({
      where: { orgId },
      data: { status: SubscriptionStatus.pastDue },
    });
  }

  /// Resolve the org id from a Stripe object's metadata, falling back to a
  /// lookup by customer/subscription id against the local mirror.
  private async resolveOrgId(
    object: Record<string, unknown>,
  ): Promise<string | null> {
    const metaOrgId = (object.metadata as { orgId?: string } | undefined)?.orgId;
    if (metaOrgId) return metaOrgId;

    const customerId = object.customer as string | undefined;
    if (customerId) {
      const byCustomer = await this.prisma.subscription.findFirst({
        where: { stripeCustomerId: customerId },
        select: { orgId: true },
      });
      if (byCustomer) return byCustomer.orgId;
    }
    const subId = object.subscription as string | undefined;
    if (subId) {
      const bySub = await this.prisma.subscription.findFirst({
        where: { stripeSubscriptionId: subId },
        select: { orgId: true },
      });
      if (bySub) return bySub.orgId;
    }
    return null;
  }

  private tierFromSubscription(stripeSub: Record<string, unknown>): PlanTier {
    const items = stripeSub.items as { data?: Array<{ price?: { id?: string } }> } | undefined;
    const priceId = items?.data?.[0]?.price?.id;
    if (priceId) {
      for (const tier of PURCHASABLE_TIERS) {
        if (this.config.get<string>(stripePriceEnvKey(tier)) === priceId) {
          return tier;
        }
      }
    }
    return PlanTier.free;
  }

  private mapStatus(stripeStatus: string): SubscriptionStatus {
    switch (stripeStatus) {
      case 'active':
        return SubscriptionStatus.active;
      case 'trialing':
        return SubscriptionStatus.trialing;
      case 'past_due':
      case 'unpaid':
        return SubscriptionStatus.pastDue;
      case 'canceled':
        return SubscriptionStatus.canceled;
      default:
        return SubscriptionStatus.incomplete;
    }
  }

  /// Returns the Stripe customer id for the org, creating the customer (and the
  /// local Subscription row) on first use.
  private async ensureCustomer(orgId: string, email: string): Promise<string> {
    const existing = await this.prisma.subscription.findUnique({
      where: { orgId },
    });
    if (existing?.stripeCustomerId) return existing.stripeCustomerId;

    const customerId = await this.stripe.createCustomer({ email, orgId });
    await this.prisma.subscription.upsert({
      where: { orgId },
      create: { orgId, stripeCustomerId: customerId },
      update: { stripeCustomerId: customerId },
    });
    return customerId;
  }

  private frontendUrl(): string {
    return this.config.get<string>('FRONTEND_URL') ?? 'http://localhost:8080';
  }

  private assertConfigured(): void {
    if (!this.stripe.enabled) {
      throw new ServiceUnavailableException(
        "Billing isn't set up on this server yet. An administrator needs to " +
          "add the Stripe API keys first.",
      );
    }
  }
}
