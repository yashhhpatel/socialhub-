import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UserTokenType } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { createHash } from 'crypto';

import { EmailService } from '../common/email/email.service';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { AccountService } from './account.service';

const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');

describe('AccountService', () => {
  let service: AccountService;
  let prisma: {
    $transaction: jest.Mock;
    user: { update: jest.Mock };
    userToken: {
      create: jest.Mock;
      updateMany: jest.Mock;
      findUnique: jest.Mock;
    };
    refreshToken: { updateMany: jest.Mock };
  };
  let usersService: { findByEmail: jest.Mock };
  let email: {
    sendEmailVerification: jest.Mock;
    sendPasswordReset: jest.Mock;
  };
  let config: { get: jest.Mock };

  beforeEach(() => {
    prisma = {
      // Execute an array of operations, or a callback, like real Prisma.
      $transaction: jest.fn().mockImplementation(async (arg) =>
        typeof arg === 'function' ? arg(prisma) : Promise.all(arg),
      ),
      user: { update: jest.fn().mockResolvedValue({}) },
      userToken: {
        create: jest.fn().mockResolvedValue({}),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUnique: jest.fn(),
      },
      refreshToken: { updateMany: jest.fn().mockResolvedValue({ count: 0 }) },
    };
    usersService = { findByEmail: jest.fn() };
    email = {
      sendEmailVerification: jest.fn().mockResolvedValue(undefined),
      sendPasswordReset: jest.fn().mockResolvedValue(undefined),
    };
    config = { get: jest.fn().mockReturnValue('https://app.example.com') };

    service = new AccountService(
      prisma as unknown as PrismaService,
      usersService as unknown as UsersService,
      email as unknown as EmailService,
      config as unknown as ConfigService,
    );
  });

  describe('sendVerificationEmail', () => {
    it('issues a verification token and emails a hash-route link with the raw token', async () => {
      await service.sendVerificationEmail('usr_1', 'jane@example.com');

      // Old unconsumed verification tokens are superseded, then a new one created.
      expect(prisma.userToken.updateMany).toHaveBeenCalledWith({
        where: { userId: 'usr_1', type: UserTokenType.email_verification, consumedAt: null },
        data: { consumedAt: expect.any(Date) },
      });
      const createArg = prisma.userToken.create.mock.calls[0][0];
      expect(createArg.data.type).toBe(UserTokenType.email_verification);
      expect(createArg.data.tokenHash).toMatch(/^[0-9a-f]{64}$/);

      const { verifyUrl, to } = email.sendEmailVerification.mock.calls[0][0];
      expect(to).toBe('jane@example.com');
      expect(verifyUrl).toMatch(
        /^https:\/\/app\.example\.com\/#\/verify-email\?token=[0-9a-f]{64}$/,
      );
      // The DB stores only the HASH of the token that was emailed. The token
      // rides in the hash-route fragment, so pull it out by pattern.
      const rawToken = verifyUrl.match(/token=([0-9a-f]{64})$/)![1];
      expect(createArg.data.tokenHash).toBe(sha256(rawToken));
    });
  });

  describe('verifyEmail', () => {
    it('marks the email verified when the token is valid', async () => {
      const raw = 'a'.repeat(64);
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok_1',
        userId: 'usr_1',
        type: UserTokenType.email_verification,
        consumedAt: null,
        expiresAt: new Date(Date.now() + 1000),
      });

      await service.verifyEmail(raw);

      expect(prisma.userToken.findUnique).toHaveBeenCalledWith({
        where: { tokenHash: sha256(raw) },
      });
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'usr_1' },
        data: { emailVerifiedAt: expect.any(Date) },
      });
    });

    it('rejects an unknown token', async () => {
      prisma.userToken.findUnique.mockResolvedValue(null);
      await expect(service.verifyEmail('nope')).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('rejects an expired token', async () => {
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok_1',
        userId: 'usr_1',
        type: UserTokenType.email_verification,
        consumedAt: null,
        expiresAt: new Date(Date.now() - 1000),
      });
      await expect(service.verifyEmail('x')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects an already-consumed token', async () => {
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok_1',
        userId: 'usr_1',
        type: UserTokenType.email_verification,
        consumedAt: new Date(),
        expiresAt: new Date(Date.now() + 1000),
      });
      await expect(service.verifyEmail('x')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects a token of the wrong type (a reset token used to verify)', async () => {
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok_1',
        userId: 'usr_1',
        type: UserTokenType.password_reset,
        consumedAt: null,
        expiresAt: new Date(Date.now() + 1000),
      });
      await expect(service.verifyEmail('x')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('rejects when a concurrent request consumed the token first (race)', async () => {
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok_1',
        userId: 'usr_1',
        type: UserTokenType.email_verification,
        consumedAt: null,
        expiresAt: new Date(Date.now() + 1000),
      });
      // The guarded update finds it already consumed.
      prisma.userToken.updateMany.mockResolvedValue({ count: 0 });

      await expect(service.verifyEmail('x')).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prisma.user.update).not.toHaveBeenCalled();
    });
  });

  describe('requestPasswordReset', () => {
    it('emails a reset link for a known account', async () => {
      usersService.findByEmail.mockResolvedValue({ id: 'usr_1', email: 'jane@example.com' });

      await service.requestPasswordReset('jane@example.com');

      expect(prisma.userToken.create).toHaveBeenCalled();
      const { resetUrl, to } = email.sendPasswordReset.mock.calls[0][0];
      expect(to).toBe('jane@example.com');
      expect(resetUrl).toContain('/#/reset-password?token=');
    });

    it('is a silent no-op for an unknown email — no token, no email, no leak', async () => {
      usersService.findByEmail.mockResolvedValue(null);

      await service.requestPasswordReset('ghost@example.com');

      expect(prisma.userToken.create).not.toHaveBeenCalled();
      expect(email.sendPasswordReset).not.toHaveBeenCalled();
    });
  });

  describe('resetPassword', () => {
    it('hashes the new password, verifies email, and revokes all sessions', async () => {
      const raw = 'b'.repeat(64);
      prisma.userToken.findUnique.mockResolvedValue({
        id: 'tok_1',
        userId: 'usr_1',
        type: UserTokenType.password_reset,
        consumedAt: null,
        expiresAt: new Date(Date.now() + 1000),
      });

      await service.resetPassword(raw, 'NewPass1!');

      const userUpdateArg = prisma.user.update.mock.calls[0][0];
      expect(userUpdateArg.where).toEqual({ id: 'usr_1' });
      expect(userUpdateArg.data.emailVerifiedAt).toBeInstanceOf(Date);
      expect(
        await bcrypt.compare('NewPass1!', userUpdateArg.data.passwordHash),
      ).toBe(true);

      // Existing sessions are killed.
      expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
        where: { userId: 'usr_1', revoked: false },
        data: { revoked: true },
      });
    });

    it('rejects an invalid reset token without touching the password', async () => {
      prisma.userToken.findUnique.mockResolvedValue(null);
      await expect(service.resetPassword('bad', 'NewPass1!')).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prisma.user.update).not.toHaveBeenCalled();
    });
  });
});
