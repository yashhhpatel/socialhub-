import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { BillingService } from './billing.service';
import { CheckoutDto } from './dto/checkout.dto';
import { StripeService } from './stripe.service';

interface AuthedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
  rawBody?: Buffer;
}

@Controller('billing')
export class BillingController {
  constructor(
    private readonly billing: BillingService,
    private readonly stripe: StripeService,
  ) {}

  /// Billing overview for the signed-in user's org.
  @UseGuards(JwtAuthGuard)
  @Get()
  overview(@Req() req: AuthedRequest) {
    return this.billing.getOverview(req.user.orgId);
  }

  /// Start a Checkout session for a plan (admin+). Returns the hosted URL to
  /// redirect the browser to.
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @HttpCode(HttpStatus.OK)
  @Post('checkout')
  checkout(
    @Req() req: AuthedRequest,
    @Body() dto: CheckoutDto,
  ): Promise<{ url: string }> {
    return this.billing.startCheckout({
      orgId: req.user.orgId,
      tier: dto.tier,
      userEmail: req.user.email,
    });
  }

  /// Open the Stripe Billing Portal (admin+) to manage the subscription.
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.admin)
  @HttpCode(HttpStatus.OK)
  @Post('portal')
  portal(@Req() req: AuthedRequest): Promise<{ url: string }> {
    return this.billing.startPortal(req.user.orgId);
  }

  /// Stripe webhook. PUBLIC — authenticated by the signed raw body, not a
  /// session. Verifies the signature over the exact raw payload, then applies
  /// the event. Always 200 for a valid event so Stripe doesn't retry endlessly.
  @HttpCode(HttpStatus.OK)
  @Post('webhook')
  async webhook(
    @Req() req: AuthedRequest,
    @Headers('stripe-signature') signature: string,
  ): Promise<{ received: boolean }> {
    const raw = req.rawBody?.toString('utf8') ?? '';
    const event = this.stripe.verifyWebhook(raw, signature ?? '');
    if (!event) {
      // Bad/unverifiable signature — tell Stripe we rejected it.
      return { received: false };
    }
    await this.billing.handleWebhook(event);
    return { received: true };
  }
}
