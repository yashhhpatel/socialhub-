import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHash } from 'crypto';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { generateTotp, generateTotpSecret } from '../common/crypto/totp.util';
import { PrismaService } from '../prisma/prisma.service';
import { MfaService } from './mfa.service';

const hashRecovery = (code: string) =>
  createHash('sha256')
    .update(code.replace(/[\s-]/g, '').toLowerCase())
    .digest('hex');

describe('MfaService', () => {
  let service: MfaService;
  let prisma: {
    $transaction: jest.Mock;
    user: { findUnique: jest.Mock; update: jest.Mock };
    mfaRecoveryCode: {
      deleteMany: jest.Mock;
      createMany: jest.Mock;
      count: jest.Mock;
      findFirst: jest.Mock;
      updateMany: jest.Mock;
    };
  };
  // A trivial "encryption" so tests can read the stored secret back out.
  const enc = {
    encrypt: (s: string) => `ENC(${s})`,
    decrypt: (s: string) => s.replace(/^ENC\(/, '').replace(/\)$/, ''),
  } as unknown as TokenEncryptionService;
  const jwt = new JwtService({ secret: 'test-secret-at-least-32-chars-long-xx' });
  const config = {
    get: jest.fn((key: string, fallback?: string) =>
      key === 'MFA_ISSUER' ? 'SocialHub' : fallback,
    ),
    getOrThrow: jest.fn(() => 'access-secret-at-least-32-chars-long'),
  } as unknown as ConfigService;

  beforeEach(() => {
    prisma = {
      $transaction: jest.fn().mockImplementation(async (ops) => {
        if (typeof ops === 'function') return ops(prisma);
        return Promise.all(ops);
      }),
      user: { findUnique: jest.fn(), update: jest.fn().mockResolvedValue({}) },
      mfaRecoveryCode: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        createMany: jest.fn().mockResolvedValue({ count: 10 }),
        count: jest.fn().mockResolvedValue(0),
        findFirst: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    service = new MfaService(
      prisma as unknown as PrismaService,
      enc,
      jwt,
      config,
    );
  });

  describe('beginSetup', () => {
    it('stores an encrypted secret (pending) and returns secret + otpauth URI', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'u1', mfaEnabled: false });

      const result = await service.beginSetup('u1', 'jane@example.com');

      expect(result.secret).toMatch(/^[A-Z2-7]+$/);
      expect(result.otpauthUri).toContain('otpauth://totp/');
      const updateArg = prisma.user.update.mock.calls[0][0];
      expect(updateArg.data.mfaSecretEnc).toBe(`ENC(${result.secret})`);
      // Pending — not enabled until a code is verified.
      expect(updateArg.data.mfaEnabled).toBeUndefined();
    });

    it('refuses if MFA is already enabled', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'u1', mfaEnabled: true });
      await expect(
        service.beginSetup('u1', 'jane@example.com'),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('enable', () => {
    it('verifies the code, enables MFA, and returns recovery codes', async () => {
      const secret = generateTotpSecret();
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        mfaEnabled: false,
        mfaSecretEnc: `ENC(${secret})`,
      });
      const code = generateTotp(secret);

      const result = await service.enable('u1', code);

      expect(result.recoveryCodes).toHaveLength(10);
      expect(prisma.mfaRecoveryCode.createMany).toHaveBeenCalled();
      const enableUpdate = prisma.user.update.mock.calls[0][0];
      expect(enableUpdate.data.mfaEnabled).toBe(true);
    });

    it('rejects a wrong code and does not enable', async () => {
      const secret = generateTotpSecret();
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        mfaEnabled: false,
        mfaSecretEnc: `ENC(${secret})`,
      });

      await expect(service.enable('u1', '000000')).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('refuses if setup was never started', async () => {
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        mfaEnabled: false,
        mfaSecretEnc: null,
      });
      await expect(service.enable('u1', '123456')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('challenge round-trip', () => {
    it('issues a challenge that verifyChallenge accepts with a valid TOTP', async () => {
      const secret = generateTotpSecret();
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        mfaEnabled: true,
        mfaSecretEnc: `ENC(${secret})`,
      });

      const token = await service.issueChallengeToken('u1');
      const userId = await service.verifyChallenge(token, generateTotp(secret));

      expect(userId).toBe('u1');
    });

    it('rejects a challenge with a wrong code', async () => {
      const secret = generateTotpSecret();
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        mfaEnabled: true,
        mfaSecretEnc: `ENC(${secret})`,
      });
      const token = await service.issueChallengeToken('u1');

      await expect(service.verifyChallenge(token, '000000')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects a garbage / forged challenge token', async () => {
      await expect(
        service.verifyChallenge('not.a.jwt', '123456'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('accepts a recovery code and burns it', async () => {
      const secret = generateTotpSecret();
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        mfaEnabled: true,
        mfaSecretEnc: `ENC(${secret})`,
      });
      prisma.mfaRecoveryCode.findFirst.mockResolvedValue({
        id: 'rc1',
        usedAt: null,
      });

      const token = await service.issueChallengeToken('u1');
      const userId = await service.verifyChallenge(token, 'abcde-12345');

      expect(userId).toBe('u1');
      // Looked up by normalized hash and marked used.
      expect(prisma.mfaRecoveryCode.findFirst).toHaveBeenCalledWith({
        where: { userId: 'u1', usedAt: null, codeHash: hashRecovery('abcde-12345') },
      });
      expect(prisma.mfaRecoveryCode.updateMany).toHaveBeenCalledWith({
        where: { id: 'rc1', usedAt: null },
        data: { usedAt: expect.any(Date) },
      });
    });
  });

  describe('disable', () => {
    it('clears the secret and codes after a valid factor', async () => {
      const secret = generateTotpSecret();
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        mfaEnabled: true,
        mfaSecretEnc: `ENC(${secret})`,
      });

      await service.disable('u1', generateTotp(secret));

      const disableUpdate = prisma.user.update.mock.calls[0][0];
      expect(disableUpdate.data).toEqual({ mfaEnabled: false, mfaSecretEnc: null });
      expect(prisma.mfaRecoveryCode.deleteMany).toHaveBeenCalledWith({
        where: { userId: 'u1' },
      });
    });

    it('refuses to disable on a wrong code', async () => {
      const secret = generateTotpSecret();
      prisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        mfaEnabled: true,
        mfaSecretEnc: `ENC(${secret})`,
      });
      prisma.mfaRecoveryCode.findFirst.mockResolvedValue(null);

      await expect(service.disable('u1', '000000')).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prisma.user.update).not.toHaveBeenCalled();
    });
  });

  describe('status', () => {
    it('reports enabled + remaining recovery codes', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'u1', mfaEnabled: true });
      prisma.mfaRecoveryCode.count.mockResolvedValue(7);

      await expect(service.status('u1')).resolves.toEqual({
        enabled: true,
        recoveryCodesRemaining: 7,
      });
    });
  });
});
