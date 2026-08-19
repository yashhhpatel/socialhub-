import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Transactional email (Milestone 11.1). Sends via SendGrid's HTTP API using
 * built-in fetch — deliberately no SDK dependency, both to keep the
 * dependency surface (and the lockfile) small and because a single templated
 * message doesn't need one.
 *
 * OPTIONAL AT BOOT, like Cloudinary/Anthropic: SENDGRID_API_KEY / EMAIL_FROM
 * are read with `get()` and are NOT in the boot schema. When they're unset
 * (a dev without an email provider), sendInvite logs the accept link instead
 * of throwing — so the invite flow is fully testable end-to-end locally,
 * and production fails loudly only if a real send is attempted while
 * misconfigured.
 */
@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);

  constructor(private readonly config: ConfigService) {}

  async sendInvite(params: {
    to: string;
    inviteUrl: string;
    orgName: string;
    role: string;
  }): Promise<void> {
    const subject = `You're invited to join ${params.orgName} on SocialHub`;
    const body =
      `You've been invited to join ${params.orgName} as ${params.role}.\n\n` +
      `Accept your invitation: ${params.inviteUrl}\n\n` +
      `This link expires in 7 days.`;

    await this.send({
      to: params.to,
      subject,
      body,
      // What to surface in dev logs when no provider is configured.
      devHint: `Accept link: ${params.inviteUrl}`,
      devContext: `invite for ${params.to}`,
    });
  }

  /**
   * Email-verification link (Phase 17.1). Sent on registration and on resend.
   * Like every send here, it degrades to a dev log when SendGrid is unset so
   * the flow is fully exercisable locally.
   */
  async sendEmailVerification(params: {
    to: string;
    verifyUrl: string;
  }): Promise<void> {
    const subject = 'Verify your SocialHub email';
    const body =
      `Welcome to SocialHub! Please confirm your email address.\n\n` +
      `Verify your email: ${params.verifyUrl}\n\n` +
      `This link expires in 24 hours. If you didn't create this account, ` +
      `you can ignore this message.`;

    await this.send({
      to: params.to,
      subject,
      body,
      devHint: `Verify link: ${params.verifyUrl}`,
      devContext: `email verification for ${params.to}`,
    });
  }

  /**
   * Password-reset link (Phase 17.1). The request endpoint always responds the
   * same whether or not the account exists, so this is only ever called for a
   * real user — but the copy still avoids confirming anything sensitive.
   */
  async sendPasswordReset(params: {
    to: string;
    resetUrl: string;
  }): Promise<void> {
    const subject = 'Reset your SocialHub password';
    const body =
      `We received a request to reset your SocialHub password.\n\n` +
      `Reset your password: ${params.resetUrl}\n\n` +
      `This link expires in 1 hour. If you didn't request this, you can ` +
      `safely ignore this email — your password won't change.`;

    await this.send({
      to: params.to,
      subject,
      body,
      devHint: `Reset link: ${params.resetUrl}`,
      devContext: `password reset for ${params.to}`,
    });
  }

  /**
   * Shared SendGrid send. OPTIONAL AT BOOT: when SENDGRID_API_KEY / EMAIL_FROM
   * are unset (a dev without an email provider) it logs `devHint` instead of
   * throwing, so every email-backed flow is testable locally; production fails
   * loudly only if a real send is attempted while misconfigured.
   */
  private async send(params: {
    to: string;
    subject: string;
    body: string;
    devHint: string;
    devContext: string;
  }): Promise<void> {
    const apiKey = this.config.get<string>('SENDGRID_API_KEY');
    const from = this.config.get<string>('EMAIL_FROM');

    if (!apiKey || !from) {
      this.logger.warn(
        `Email provider not configured — ${params.devContext} not sent. ` +
          params.devHint,
      );
      return;
    }

    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [{ to: [{ email: params.to }] }],
        from: { email: from },
        subject: params.subject,
        content: [{ type: 'text/plain', value: params.body }],
      }),
    });

    if (!response.ok) {
      throw new Error(
        `Email send failed (${params.devContext}): ${response.status} ${await response.text()}`,
      );
    }
  }
}
