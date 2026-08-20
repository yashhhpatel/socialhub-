import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import { createHash, randomBytes } from 'crypto';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import {
  buildOtpauthUri,
  generateTotpSecret,
  verifyTotp,
} from '../common/crypto/totp.util';
import { PrismaService } from '../prisma/prisma.service';
import {
  MfaEnabledResponseDto,
  MfaSetupResponseDto,
  MfaStatusDto,
} from './dto/mfa-response.dto';

const RECOVERY_CODE_COUNT = 10;
const RECOVERY_CODE_BYTES = 5; // 10 hex chars, shown as xxxxx-xxxxx
const CHALLENGE_TTL = '5m';
const CHALLENGE_TYPE = 'mfa_challenge';

interface ChallengePayload {
  sub: string;
  typ: typeof CHALLENGE_TYPE;
}

/**
 * TOTP multi-factor auth (Phase 17.3). Owns enrollment (setup -> enable),
 * removal (disable), the login second-factor step, and recovery codes.
 *
 * The TOTP secret is encrypted at rest via TokenEncryptionService — a stolen
 * DB dump never yields a working authenticator seed. The login challenge is a
 * short-lived JWT signed with a DEDICATED secret (never the access-token
 * secret) and stamped `typ: mfa_challenge`, so it can neither be used as an
 * access token nor be minted by anything but this service.
 */
@Injectable()
export class MfaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenEncryption: TokenEncryptionService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
  ) {}

  /** Dedicated challenge-signing secret, distinct from the access-token secret. */
  private challengeSecret(): string {
    return (
      this.config.get<string>('MFA_CHALLENGE_SECRET') ??
      `${this.config.getOrThrow<string>('JWT_ACCESS_SECRET')}:mfa-challenge`
    );
  }

  private issuer(): string {
    return this.config.get<string>('MFA_ISSUER', 'SocialHub');
  }

  /**
   * Begin enrollment: mint a secret, store it encrypted (pending — mfaEnabled
   * stays false until the first code is verified), and hand back the secret +
   * otpauth URI. Re-running before enabling simply rotates the pending secret.
   */
  async beginSetup(userId: string, email: string): Promise<MfaSetupResponseDto> {
    const user = await this.getUser(userId);
    if (user.mfaEnabled) {
      throw new BadRequestException('MFA is already enabled for this account.');
    }

    const secret = generateTotpSecret();
    await this.prisma.user.update({
      where: { id: userId },
      data: { mfaSecretEnc: this.tokenEncryption.encrypt(secret) },
    });

    return {
      secret,
      otpauthUri: buildOtpauthUri({
        secret,
        accountName: email,
        issuer: this.issuer(),
      }),
    };
  }

  /**
   * Finish enrollment: verify a code against the pending secret, flip MFA on,
   * and issue a fresh set of recovery codes (returned once, stored hashed).
   */
  async enable(userId: string, code: string): Promise<MfaEnabledResponseDto> {
    const user = await this.getUser(userId);
    if (user.mfaEnabled) {
      throw new BadRequestException('MFA is already enabled for this account.');
    }
    if (!user.mfaSecretEnc) {
      throw new BadRequestException('Start MFA setup before enabling it.');
    }

    const secret = this.tokenEncryption.decrypt(user.mfaSecretEnc);
    if (!verifyTotp(secret, code)) {
      throw new BadRequestException('That code is incorrect. Try again.');
    }

    const recoveryCodes = this.generateRecoveryCodes();
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { mfaEnabled: true },
      }),
      // Clear any prior codes (defensive — there shouldn't be any yet).
      this.prisma.mfaRecoveryCode.deleteMany({ where: { userId } }),
      this.prisma.mfaRecoveryCode.createMany({
        data: recoveryCodes.map((c) => ({ userId, codeHash: this.hash(c) })),
      }),
    ]);

    return { recoveryCodes };
  }

  /**
   * Turn MFA off. Requires a valid current second factor (TOTP or a recovery
   * code) so a walk-up attacker at an unlocked session can't silently strip
   * it. Wipes the secret and all recovery codes.
   */
  async disable(userId: string, code: string): Promise<void> {
    const user = await this.getUser(userId);
    if (!user.mfaEnabled) {
      throw new BadRequestException('MFA is not enabled for this account.');
    }

    const ok = await this.verifySecondFactor(user, code);
    if (!ok) {
      throw new BadRequestException('That code is incorrect. Try again.');
    }

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { mfaEnabled: false, mfaSecretEnc: null },
      }),
      this.prisma.mfaRecoveryCode.deleteMany({ where: { userId } }),
    ]);
  }

  async status(userId: string): Promise<MfaStatusDto> {
    const user = await this.getUser(userId);
    const remaining = user.mfaEnabled
      ? await this.prisma.mfaRecoveryCode.count({
          where: { userId, usedAt: null },
        })
      : 0;
    return { enabled: user.mfaEnabled, recoveryCodesRemaining: remaining };
  }

  /** Short-lived token proving password success, exchanged at mfa/verify. */
  async issueChallengeToken(userId: string): Promise<string> {
    const payload: ChallengePayload = { sub: userId, typ: CHALLENGE_TYPE };
    return this.jwtService.signAsync(payload, {
      secret: this.challengeSecret(),
      expiresIn: CHALLENGE_TTL,
    });
  }

  /**
   * Exchange a challenge token + second factor for the verified user id (the
   * caller — AuthService — then issues the real session). Throws 401 on a bad
   * or expired challenge, and on a wrong code.
   */
  async verifyChallenge(challengeToken: string, code: string): Promise<string> {
    let payload: ChallengePayload;
    try {
      payload = await this.jwtService.verifyAsync<ChallengePayload>(
        challengeToken,
        { secret: this.challengeSecret() },
      );
    } catch {
      throw new UnauthorizedException('Your MFA session expired. Please log in again.');
    }
    if (payload.typ !== CHALLENGE_TYPE || !payload.sub) {
      throw new UnauthorizedException('Invalid MFA session.');
    }

    const user = await this.getUser(payload.sub);
    if (!user.mfaEnabled) {
      // MFA was turned off between login and verify — nothing to check.
      throw new UnauthorizedException('MFA is not enabled for this account.');
    }

    const ok = await this.verifySecondFactor(user, code);
    if (!ok) {
      throw new UnauthorizedException('That code is incorrect. Try again.');
    }
    return user.id;
  }

  /**
   * True if `code` is either the current TOTP or an unused recovery code. A
   * matching recovery code is burned (marked used) as a side effect — atomic,
   * so it can't be redeemed twice under a race.
   */
  private async verifySecondFactor(user: User, code: string): Promise<boolean> {
    if (user.mfaSecretEnc) {
      const secret = this.tokenEncryption.decrypt(user.mfaSecretEnc);
      if (verifyTotp(secret, code)) return true;
    }

    // Fall back to recovery codes. Normalize away spacing/case/hyphens so the
    // user can type a code however it was printed.
    const normalized = code.replace(/[\s-]/g, '').toLowerCase();
    if (!normalized) return false;

    const match = await this.prisma.mfaRecoveryCode.findFirst({
      where: { userId: user.id, usedAt: null, codeHash: this.hash(normalized) },
    });
    if (!match) return false;

    const burned = await this.prisma.mfaRecoveryCode.updateMany({
      where: { id: match.id, usedAt: null },
      data: { usedAt: new Date() },
    });
    return burned.count === 1;
  }

  private generateRecoveryCodes(): string[] {
    return Array.from({ length: RECOVERY_CODE_COUNT }, () => {
      const hex = randomBytes(RECOVERY_CODE_BYTES).toString('hex'); // 10 chars
      return `${hex.slice(0, 5)}-${hex.slice(5)}`;
    });
  }

  /** Recovery codes are hashed after normalization (strip spacing/hyphens). */
  private hash(code: string): string {
    const normalized = code.replace(/[\s-]/g, '').toLowerCase();
    return createHash('sha256').update(normalized).digest('hex');
  }

  private async getUser(userId: string): Promise<User> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();
    return user;
  }
}
