import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Delegates to the 'jwt' Passport strategy registered by JwtStrategy.
 * Usable from any module (e.g. UsersModule for GET /users/me) via a plain
 * TypeScript import — this does not require importing AuthModule itself,
 * which avoids a circular module dependency (AuthModule already imports
 * UsersModule for UsersService).
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
