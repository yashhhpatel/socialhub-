import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import { createHash, randomBytes, randomUUID } from 'crypto';

import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from './auth.service';
import { AuthResponseDto } from './dto/auth-response.dto';
import { defaultOrgName } from './default-org-name';

const GOOGLE_AUTH_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const VALID_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];

const HANDOFF_TOKEN_BYTES = 48;
const HANDOFF_TTL_MS = 2 * 60 * 1000; // 2 minutes — just long enough to redirect
const STATE_TTL = '10m';

interface GoogleIdTokenClaims {
  iss?: string;
  aud?: string;
  sub?: string;
  email?: string;
  email_verified?: boolean | string;
  exp?: number;
}

/**
 * "Continue with Google" via the server-side authorization-code flow.
 *
 * The browser never handles Google's tokens: our custom button sends it to
 * /auth/google/start, we redirect to Google, Google calls us back, and we
 * exchange the code for an id_token *server-side* using the client secret.
 * Because that id_token comes straight from Google's token endpoint over an
 * authenticated TLS channel, its origin is already proven — we still validate
 * its claims (issuer, audience, expiry, verified email) before trusting it.
 *
 * The resulting session is handed to the frontend via a single-use, short-
 * lived ticket in the redirect URL (never the access/refresh tokens
 * themselves), which the SPA swaps for the normal session JSON at
 * /auth/google/exchange.
 *
 * Optional at boot: with no GOOGLE_CLIENT_ID/SECRET the button is inert and
 * /auth/google/start returns 503 — same degrade-gracefully pattern as the
 * other third-party integrations (Stripe, Cloudinary, AI).
 */
@Injectable()
export class GoogleAuthService {
  private readonly logger = new Logger(GoogleAuthService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
  ) {}

  get enabled(): boolean {
    return Boolean(this.clientId && this.clientSecret);
  }

  /** Builds the Google consent URL to redirect the browser to. */
  async buildConsentUrl(): Promise<string> {
    this.assertEnabled();
    // Signed, self-verifying state — tamper-proof and time-boxed without any
    // server-side session store (there are no login cookies in this app).
    const state = await this.jwt.signAsync(
      { purpose: 'google_oauth_state', nonce: randomUUID() },
      { expiresIn: STATE_TTL },
    );
    const params = new URLSearchParams({
      client_id: this.clientId!,
      redirect_uri: this.redirectUri,
      response_type: 'code',
      scope: 'openid email profile',
      access_type: 'online',
      prompt: 'select_account',
      state,
    });
    return `${GOOGLE_AUTH_ENDPOINT}?${params.toString()}`;
  }

  /**
   * Handles Google's callback: validates state, exchanges the code, verifies
   * the id_token's claims, resolves the account (find-or-create-and-link), and
   * returns the frontend URL to redirect to — carrying only a single-use
   * handoff ticket.
   */
  async handleCallback(code: string, state: string): Promise<string> {
    this.assertEnabled();
    await this.verifyState(state);

    const claims = await this.exchangeCodeForClaims(code);
    const userId = await this.resolveUser(claims);
    const ticket = await this.mintHandoffTicket(userId);

    return `${this.frontendUrl}/#/auth/google?ticket=${encodeURIComponent(ticket)}`;
  }

  /** The URL to bounce the browser to when the flow fails before a session. */
  failureRedirect(): string {
    return `${this.frontendUrl}/#/login?error=google`;
  }

  /**
   * Swaps a single-use handoff ticket for a real session — same response shape
   * every other login path returns.
   */
  async exchangeTicket(rawTicket: string): Promise<AuthResponseDto> {
    const tokenHash = this.hash(rawTicket);
    const record = await this.prisma.userToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (
      !record ||
      record.type !== 'google_login_handoff' ||
      record.consumedAt !== null ||
      record.expiresAt < new Date() ||
      !record.user
    ) {
      throw new UnauthorizedException('This login link is invalid or has expired.');
    }

    // Single-use: burn it before issuing the session.
    await this.prisma.userToken.update({
      where: { id: record.id },
      data: { consumedAt: new Date() },
    });

    return this.auth.issueSession(
      record.user.id,
      record.user.email,
      record.user.role,
      record.user.orgId,
    );
  }

  // --- internals ---

  private async exchangeCodeForClaims(
    code: string,
  ): Promise<Required<Pick<GoogleIdTokenClaims, 'sub' | 'email'>>> {
    let idToken: string;
    try {
      const res = await fetch(GOOGLE_TOKEN_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          code,
          client_id: this.clientId!,
          client_secret: this.clientSecret!,
          redirect_uri: this.redirectUri,
          grant_type: 'authorization_code',
        }).toString(),
      });
      if (!res.ok) {
        this.logger.warn(`Google token exchange failed: HTTP ${res.status}`);
        throw new Error('token-exchange');
      }
      const body = (await res.json()) as { id_token?: string };
      if (!body.id_token) throw new Error('no-id-token');
      idToken = body.id_token;
    } catch (err) {
      this.logger.warn(
        `Google code exchange error: ${err instanceof Error ? err.message : err}`,
      );
      throw new UnauthorizedException('Google sign-in could not be completed.');
    }

    const claims = this.decodeIdToken(idToken);

    // The id_token came directly from Google's token endpoint over TLS,
    // authenticated with our client secret — so its signature is implicitly
    // trusted. We still enforce the semantic claims.
    const emailVerified =
      claims.email_verified === true || claims.email_verified === 'true';
    const audienceOk = claims.aud === this.clientId;
    const issuerOk = !!claims.iss && VALID_ISSUERS.includes(claims.iss);
    const notExpired = !!claims.exp && claims.exp * 1000 > Date.now();

    if (
      !issuerOk ||
      !audienceOk ||
      !notExpired ||
      !claims.sub ||
      !claims.email ||
      !emailVerified
    ) {
      throw new UnauthorizedException('Google sign-in could not be verified.');
    }

    return { sub: claims.sub, email: claims.email.trim().toLowerCase() };
  }

  private decodeIdToken(idToken: string): GoogleIdTokenClaims {
    const parts = idToken.split('.');
    if (parts.length !== 3) {
      throw new UnauthorizedException('Google sign-in could not be verified.');
    }
    try {
      const payload = Buffer.from(parts[1], 'base64url').toString('utf8');
      return JSON.parse(payload) as GoogleIdTokenClaims;
    } catch {
      throw new UnauthorizedException('Google sign-in could not be verified.');
    }
  }

  /**
   * Find-or-create by Google identity:
   *  1. Already linked (googleId match) → that user.
   *  2. Email exists → LINK Google to it (no duplicate account).
   *  3. New → create the user and their default workspace atomically
   *     (Option A), marking the email verified since Google vouched for it.
   */
  private async resolveUser(claims: {
    sub: string;
    email: string;
  }): Promise<string> {
    const byGoogle = await this.prisma.user.findUnique({
      where: { googleId: claims.sub },
    });
    if (byGoogle) return byGoogle.id;

    const byEmail = await this.prisma.user.findUnique({
      where: { email: claims.email },
    });
    if (byEmail) {
      // Link, unless a *different* Google account is somehow already attached.
      if (byEmail.googleId && byEmail.googleId !== claims.sub) {
        throw new UnauthorizedException(
          'This email is already linked to a different Google account.',
        );
      }
      if (!byEmail.googleId) {
        await this.prisma.user.update({
          where: { id: byEmail.id },
          data: {
            googleId: claims.sub,
            // Google-verified email — mark it verified if it wasn't already.
            emailVerifiedAt: byEmail.emailVerifiedAt ?? new Date(),
          },
        });
      }
      return byEmail.id;
    }

    const created = await this.prisma.$transaction(async (tx) => {
      const organization = await tx.organization.create({
        data: { name: defaultOrgName(claims.email) },
      });
      return tx.user.create({
        data: {
          email: claims.email,
          passwordHash: null,
          googleId: claims.sub,
          orgId: organization.id,
          role: UserRole.owner,
          emailVerifiedAt: new Date(),
        },
      });
    });
    return created.id;
  }

  private async mintHandoffTicket(userId: string): Promise<string> {
    const raw = randomBytes(HANDOFF_TOKEN_BYTES).toString('hex');
    await this.prisma.userToken.create({
      data: {
        userId,
        type: 'google_login_handoff',
        tokenHash: this.hash(raw),
        expiresAt: new Date(Date.now() + HANDOFF_TTL_MS),
      },
    });
    return raw;
  }

  private async verifyState(state: string): Promise<void> {
    try {
      const payload = await this.jwt.verifyAsync<{ purpose?: string }>(state);
      if (payload.purpose !== 'google_oauth_state') throw new Error('purpose');
    } catch {
      throw new UnauthorizedException('Google sign-in state was invalid or expired.');
    }
  }

  private assertEnabled(): void {
    if (!this.enabled) {
      throw new ServiceUnavailableException(
        'Google sign-in is not configured on this server.',
      );
    }
  }

  private hash(raw: string): string {
    return createHash('sha256').update(raw).digest('hex');
  }

  private get clientId(): string | undefined {
    return this.config.get<string>('GOOGLE_CLIENT_ID');
  }

  private get clientSecret(): string | undefined {
    return this.config.get<string>('GOOGLE_CLIENT_SECRET');
  }

  private get redirectUri(): string {
    return this.config.get<string>(
      'GOOGLE_REDIRECT_URI',
      'http://localhost:3000/auth/google/callback',
    );
  }

  private get frontendUrl(): string {
    return this.config
      .get<string>('FRONTEND_URL', 'http://localhost:8080')
      .replace(/\/+$/, '');
  }
}
