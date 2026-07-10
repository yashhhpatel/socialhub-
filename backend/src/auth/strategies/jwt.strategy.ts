import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { UserRole } from '@prisma/client';
import { ExtractJwt, Strategy } from 'passport-jwt';

import { JwtPayload } from '../interfaces/jwt-payload.interface';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
    });
  }

  // Whatever this returns becomes `req.user` on any route behind
  // JwtAuthGuard — including role/orgId now, which RolesGuard (see
  // src/common/guards/roles.guard.ts) reads directly from here rather
  // than doing an extra DB lookup on every request. This comes straight
  // from the token payload, not a fresh DB read, so it must never be
  // trusted for anything beyond authorization checks. Routes needing
  // current, authoritative user state (e.g. GET /users/me) still look the
  // user up again via UsersService.
  validate(payload: JwtPayload): {
    userId: string;
    email: string;
    role: UserRole;
    orgId: string;
  } {
    return {
      userId: payload.sub,
      email: payload.email,
      role: payload.role,
      orgId: payload.orgId,
    };
  }
}
