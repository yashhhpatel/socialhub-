import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import type { SignOptions } from 'jsonwebtoken';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { EmailModule } from '../common/email/email.module';
import { RateLimitModule } from '../common/rate-limit/rate-limit.module';
import { UsersModule } from '../users/users.module';
import { AccountService } from './account.service';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { AuthThrottleService } from './auth-throttle.service';
import { GoogleAuthController } from './google-auth.controller';
import { GoogleAuthService } from './google-auth.service';
import { MfaService } from './mfa.service';
import { SsoController } from './sso/sso.controller';
import { SsoService } from './sso/sso.service';
import { JwtStrategy } from './strategies/jwt.strategy';

@Module({
  imports: [
    UsersModule,
    EmailModule,
    RateLimitModule,
    PassportModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
        signOptions: {
          // jsonwebtoken's SignOptions types expiresIn as a template-literal
          // union (e.g. '15m') rather than plain `string`, so a
          // config-driven value needs an explicit cast here. Joi already
          // guarantees this is a string at boot (see env.validation.ts);
          // jsonwebtoken itself parses arbitrary '<n><unit>' strings fine
          // at runtime regardless of this compile-time narrowing.
          expiresIn: configService.get<string>(
            'JWT_ACCESS_EXPIRES_IN',
            '15m',
          ) as SignOptions['expiresIn'],
        },
      }),
    }),
  ],
  controllers: [AuthController, GoogleAuthController, SsoController],
  providers: [
    AuthService,
    AccountService,
    AuthThrottleService,
    MfaService,
    GoogleAuthService,
    TokenEncryptionService,
    JwtStrategy,
    SsoService,
  ],
  // AccountService is exported so the admin panel (Phase 21.4) can reuse the
  // resend-verification / password-reset flows without duplicating them.
  exports: [AccountService],
})
export class AuthModule {}
