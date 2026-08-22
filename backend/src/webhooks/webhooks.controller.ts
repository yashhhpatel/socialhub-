import {
  Controller,
  ForbiddenException,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Logger,
  NotFoundException,
  Param,
  Post,
  Query,
  Req,
  Res,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Platform } from '@prisma/client';
import { Request, Response } from 'express';

import { verifyMetaWebhookSignature } from '../common/crypto/meta-webhook-signature.util';
import { WebhooksService, MetaWebhookPayload } from './webhooks.service';

/** Express request with the raw body Nest captures (rawBody: true in main.ts). */
interface RawBodyRequest extends Request {
  rawBody?: Buffer;
}

/** Meta platforms that share the Graph API webhook protocol. */
const META_PLATFORMS = new Set<string>([
  Platform.instagram,
  Platform.facebook,
  Platform.threads,
]);

/**
 * Inbound platform webhooks (Phase 20). PUBLIC — trust comes from the verified
 * signature, never a session. Meta (IG/FB/Threads) is the supported protocol:
 * a GET verification handshake and signed POST deliveries. X and LinkedIn don't
 * offer post-status webhooks relevant to this app, so they're intentionally not
 * wired.
 */
@Controller('webhooks')
export class WebhooksController {
  private readonly logger = new Logger(WebhooksController.name);

  constructor(
    private readonly webhooks: WebhooksService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Meta verification handshake: echo `hub.challenge` iff the mode is
   * `subscribe` and `hub.verify_token` matches our configured token.
   */
  @Get(':platform')
  verify(
    @Param('platform') platform: string,
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') token: string,
    @Query('hub.challenge') challenge: string,
    @Res() res: Response,
  ): void {
    if (!META_PLATFORMS.has(platform)) {
      throw new NotFoundException('Unknown webhook platform.');
    }
    const expected = this.config.get<string>('META_WEBHOOK_VERIFY_TOKEN');
    if (mode === 'subscribe' && expected && token === expected) {
      res.status(HttpStatus.OK).type('text/plain').send(challenge ?? '');
      return;
    }
    res.status(HttpStatus.FORBIDDEN).type('text/plain').send('Forbidden');
  }

  /**
   * Signed event delivery. Verifies `X-Hub-Signature-256` over the raw body
   * with the platform's app secret, then dispatches idempotently. Always 200 on
   * a valid signature (even for unmapped events) so Meta doesn't retry forever.
   */
  @Post(':platform')
  @HttpCode(HttpStatus.OK)
  async receive(
    @Param('platform') platform: string,
    @Headers('x-hub-signature-256') signature: string,
    @Req() req: RawBodyRequest,
  ): Promise<{ received: boolean; handled: number }> {
    if (!META_PLATFORMS.has(platform)) {
      throw new NotFoundException('Unknown webhook platform.');
    }
    const appSecret = this.metaAppSecret(platform);
    const raw = req.rawBody?.toString('utf8');

    if (!verifyMetaWebhookSignature(raw, signature, appSecret)) {
      // One opaque error — never reveal which check failed.
      throw new ForbiddenException('Invalid webhook signature.');
    }

    let payload: MetaWebhookPayload;
    try {
      payload = JSON.parse(raw as string) as MetaWebhookPayload;
    } catch {
      // Signature already proved authenticity; a body we can't parse is logged
      // (no secrets) and acknowledged so it isn't retried forever.
      this.logger.warn(`Unparseable ${platform} webhook body.`);
      return { received: true, handled: 0 };
    }

    const { handled } = await this.webhooks.handleMetaEvent(
      platform as Platform,
      payload,
    );
    return { received: true, handled };
  }

  /** Same env-var resolution the compliance callbacks use (per-platform secret). */
  private metaAppSecret(platform: string): string | null {
    switch (platform) {
      case Platform.facebook:
        return (
          this.config.get<string>('FACEBOOK_APP_SECRET') ??
          this.config.get<string>('FACEBOOK_CLIENT_SECRET') ??
          null
        );
      case Platform.instagram:
        return this.config.get<string>('INSTAGRAM_CLIENT_SECRET') ?? null;
      case Platform.threads:
        return this.config.get<string>('THREADS_CLIENT_SECRET') ?? null;
      default:
        return null;
    }
  }
}
