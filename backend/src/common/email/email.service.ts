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
    const apiKey = this.config.get<string>('SENDGRID_API_KEY');
    const from = this.config.get<string>('EMAIL_FROM');

    const subject = `You're invited to join ${params.orgName} on SocialHub`;
    const body =
      `You've been invited to join ${params.orgName} as ${params.role}.\n\n` +
      `Accept your invitation: ${params.inviteUrl}\n\n` +
      `This link expires in 7 days.`;

    if (!apiKey || !from) {
      this.logger.warn(
        `Email provider not configured — invite for ${params.to} not sent. ` +
          `Accept link: ${params.inviteUrl}`,
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
        subject,
        content: [{ type: 'text/plain', value: body }],
      }),
    });

    if (!response.ok) {
      throw new Error(
        `Invite email send failed: ${response.status} ${await response.text()}`,
      );
    }
  }
}
