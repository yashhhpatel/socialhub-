import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, timingSafeEqual } from 'crypto';

/// Minimal Stripe client over the REST API using built-in fetch — no SDK
/// dependency, matching how EmailService (SendGrid) and the AI gateway talk to
/// their providers. Everything is form-encoded, as Stripe's API expects.
///
/// OPTIONAL AT BOOT: STRIPE_SECRET_KEY / STRIPE_WEBHOOK_SECRET are read with
/// `get()` and are NOT in the boot schema. When the secret key is unset,
/// [enabled] is false and the callers surface a clean "billing isn't set up"
/// error instead of attempting a live call — the same degradation the OAuth
/// adapters use.
@Injectable()
export class StripeService {
  private readonly logger = new Logger(StripeService.name);
  private static readonly base = 'https://api.stripe.com/v1';

  constructor(private readonly config: ConfigService) {}

  get enabled(): boolean {
    return !!this.config.get<string>('STRIPE_SECRET_KEY');
  }

  private get secretKey(): string {
    return this.config.getOrThrow<string>('STRIPE_SECRET_KEY');
  }

  /// Creates a Stripe Customer and returns its id.
  async createCustomer(params: {
    email: string;
    orgId: string;
  }): Promise<string> {
    const data = await this.post('/customers', {
      email: params.email,
      'metadata[orgId]': params.orgId,
    });
    return data.id as string;
  }

  /// Creates a Checkout Session for a subscription and returns its hosted URL.
  async createCheckoutSession(params: {
    customerId: string;
    priceId: string;
    successUrl: string;
    cancelUrl: string;
    orgId: string;
  }): Promise<string> {
    const data = await this.post('/checkout/sessions', {
      mode: 'subscription',
      customer: params.customerId,
      'line_items[0][price]': params.priceId,
      'line_items[0][quantity]': '1',
      success_url: params.successUrl,
      cancel_url: params.cancelUrl,
      'metadata[orgId]': params.orgId,
      'subscription_data[metadata][orgId]': params.orgId,
    });
    return data.url as string;
  }

  /// Creates a Billing Portal session and returns its URL.
  async createPortalSession(params: {
    customerId: string;
    returnUrl: string;
  }): Promise<string> {
    const data = await this.post('/billing_portal/sessions', {
      customer: params.customerId,
      return_url: params.returnUrl,
    });
    return data.url as string;
  }

  /// Fetches a subscription (used to resolve plan/price on webhook events that
  /// only carry the subscription id).
  async getSubscription(id: string): Promise<Record<string, unknown>> {
    return this.get(`/subscriptions/${id}`);
  }

  /// Verifies a Stripe webhook signature (scheme: `t=<ts>,v1=<sig>` where sig =
  /// HMAC-SHA256 of `${t}.${rawBody}` keyed on the webhook secret) and returns
  /// the parsed event, or null if verification fails or isn't configured.
  verifyWebhook(rawBody: string, signatureHeader: string): Record<string, unknown> | null {
    const secret = this.config.get<string>('STRIPE_WEBHOOK_SECRET');
    if (!secret || !signatureHeader) return null;

    const parts = Object.fromEntries(
      signatureHeader.split(',').map((kv) => {
        const [k, v] = kv.split('=');
        return [k?.trim(), v?.trim()];
      }),
    );
    const timestamp = parts['t'];
    const provided = parts['v1'];
    if (!timestamp || !provided) return null;

    const expected = createHmac('sha256', secret)
      .update(`${timestamp}.${rawBody}`)
      .digest('hex');

    const a = Buffer.from(expected);
    const b = Buffer.from(provided);
    if (a.length !== b.length || !timingSafeEqual(a, b)) return null;

    try {
      return JSON.parse(rawBody) as Record<string, unknown>;
    } catch {
      return null;
    }
  }

  private async post(
    path: string,
    body: Record<string, string>,
  ): Promise<Record<string, unknown>> {
    const response = await fetch(`${StripeService.base}${path}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.secretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams(body).toString(),
    });
    return this.parse(response, `POST ${path}`);
  }

  private async get(path: string): Promise<Record<string, unknown>> {
    const response = await fetch(`${StripeService.base}${path}`, {
      headers: { Authorization: `Bearer ${this.secretKey}` },
    });
    return this.parse(response, `GET ${path}`);
  }

  private async parse(
    response: Response,
    label: string,
  ): Promise<Record<string, unknown>> {
    if (!response.ok) {
      const text = await response.text();
      this.logger.error(`Stripe ${label} failed: ${response.status} ${text}`);
      throw new Error(`Stripe request failed: ${response.status}`);
    }
    return (await response.json()) as Record<string, unknown>;
  }
}
