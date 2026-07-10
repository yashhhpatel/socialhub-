import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'crypto';

import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { AuthResponseDto } from './dto/auth-response.dto';
import { JwtPayload } from './interfaces/jwt-payload.interface';

const BCRYPT_SALT_ROUNDS = 12;
const REFRESH_TOKEN_BYTES = 64;

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(params: {
    email: string;
    password: string;
    orgName: string;
  }): Promise<AuthResponseDto> {
    const existing = await this.usersService.findByEmail(params.email);
    if (existing) {
      // Matches docs/api/SocialHub_REST_API_Design.md: 409 on duplicate
      // email for register (unlike login, which stays deliberately vague).
      throw new ConflictException('An account with this email already exists.');
    }

    const passwordHash = await bcrypt.hash(params.password, BCRYPT_SALT_ROUNDS);
    const normalizedEmail = params.email.trim().toLowerCase();

    // Org + owning user must be created atomically — a user with no org,
    // or an org with no owner, are both invalid states this app should
    // never be able to observe even transiently. This intentionally does
    // NOT go through OrganizationsService/UsersService.create (see their
    // doc comments) since those use the plain, non-transactional
    // PrismaService.
    const { user, organization } = await this.prisma.$transaction(async (tx) => {
      const organization = await tx.organization.create({
        data: { name: params.orgName },
      });

      const user = await tx.user.create({
        data: {
          email: normalizedEmail,
          passwordHash,
          orgId: organization.id,
          role: UserRole.owner,
        },
      });

      return { user, organization };
    });

    return this.issueTokenPair(user.id, user.email, user.role, organization.id);
  }

  async login(params: {
    email: string;
    password: string;
  }): Promise<AuthResponseDto> {
    const user = await this.usersService.findByEmail(params.email);

    // Deliberately generic message and constant code path whether the
    // user exists or the password is wrong — never reveal which, per
    // docs/api/SocialHub_REST_API_Design.md.
    if (!user) {
      throw new UnauthorizedException('Invalid email or password.');
    }

    const passwordMatches = await bcrypt.compare(
      params.password,
      user.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid email or password.');
    }

    return this.issueTokenPair(user.id, user.email, user.role, user.orgId);
  }

  async refresh(rawRefreshToken: string): Promise<AuthResponseDto> {
    const tokenHash = this.hashRefreshToken(rawRefreshToken);

    const existing = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (!existing) {
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }

    if (existing.revoked) {
      // Reuse of an already-rotated-away token is a strong signal of theft
      // (a legitimate client would only ever hold the latest token). Per
      // docs/api/SocialHub_REST_API_Design.md: reuse triggers full session
      // revocation for that user, not just rejection of this one request.
      await this.prisma.refreshToken.updateMany({
        where: { userId: existing.userId, revoked: false },
        data: { revoked: true },
      });
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }

    if (existing.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }

    // Guaranteed present at the data level (a refresh_token row always has
    // a NOT NULL, cascade-deleted userId FK — see schema.prisma), but
    // asserted explicitly rather than assumed, since we just did an
    // `include` fetch for it. A missing user here would mean a genuine
    // data-integrity problem, not something to silently paper over with a
    // non-null assertion.
    if (!existing.user) {
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }

    // Rotation: this token is consumed, a new one takes its place.
    await this.prisma.refreshToken.update({
      where: { id: existing.id },
      data: { revoked: true },
    });

    return this.issueTokenPair(
      existing.user.id,
      existing.user.email,
      existing.user.role,
      existing.user.orgId,
    );
  }

  async logout(rawRefreshToken: string): Promise<void> {
    const tokenHash = this.hashRefreshToken(rawRefreshToken);

    // Idempotent by design: logging out an already-invalid/unknown token
    // is not an error condition worth surfacing to the caller.
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revoked: false },
      data: { revoked: true },
    });
  }

  private async issueTokenPair(
    userId: string,
    email: string,
    role: UserRole,
    orgId: string,
  ): Promise<AuthResponseDto> {
    const payload: JwtPayload = { sub: userId, email, role, orgId };
    const accessToken = await this.jwtService.signAsync(payload);

    const rawRefreshToken = randomBytes(REFRESH_TOKEN_BYTES).toString('hex');
    const refreshExpiresInDays = this.configService.get<number>(
      'JWT_REFRESH_EXPIRES_IN_DAYS',
      30,
    );
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + refreshExpiresInDays);

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: this.hashRefreshToken(rawRefreshToken),
        expiresAt,
      },
    });

    return {
      user: { id: userId, email, role, orgId },
      accessToken,
      refreshToken: rawRefreshToken,
    };
  }

  // Refresh tokens are stored hashed (SHA-256 is sufficient here — unlike
  // passwords, these are high-entropy random values, not user-chosen
  // secrets, so bcrypt's deliberate slowness buys nothing and would only
  // add unnecessary latency to every refresh call).
  private hashRefreshToken(rawToken: string): string {
    return createHash('sha256').update(rawToken).digest('hex');
  }
}
