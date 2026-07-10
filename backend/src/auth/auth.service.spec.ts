import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let authService: AuthService;
  let usersService: jest.Mocked<Pick<UsersService, 'findByEmail'>>;
  let prisma: {
    $transaction: jest.Mock;
    refreshToken: {
      findUnique: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      updateMany: jest.Mock;
    };
  };
  let txOrganizationCreate: jest.Mock;
  let txUserCreate: jest.Mock;

  beforeEach(async () => {
    usersService = {
      findByEmail: jest.fn(),
    };

    txOrganizationCreate = jest.fn();
    txUserCreate = jest.fn();

    prisma = {
      // Runs the callback against a fake transaction client exposing
      // organization.create/user.create — mirrors what
      // AuthService.register actually does with a real Prisma transaction.
      $transaction: jest.fn().mockImplementation(async (fn) =>
        fn({
          organization: { create: txOrganizationCreate },
          user: { create: txUserCreate },
        }),
      ),
      refreshToken: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      imports: [
        JwtModule.register({
          secret: 'test-secret-at-least-32-characters-long',
          signOptions: { expiresIn: '15m' },
        }),
      ],
      providers: [
        AuthService,
        { provide: UsersService, useValue: usersService },
        { provide: PrismaService, useValue: prisma },
        {
          provide: ConfigService,
          useValue: { get: jest.fn().mockReturnValue(30) },
        },
      ],
    }).compile();

    authService = module.get(AuthService);
  });

  describe('register', () => {
    it('creates the org and owning user atomically, hashes the password, and issues tokens', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      txOrganizationCreate.mockResolvedValue({
        id: 'org_1',
        name: 'Acme Inc.',
        planTier: 'free',
        requiresApproval: false,
        createdAt: new Date(),
      });
      txUserCreate.mockImplementation(async ({ data }) => ({
        id: 'usr_1',
        email: data.email,
        passwordHash: data.passwordHash,
        role: data.role,
        orgId: data.orgId,
        createdAt: new Date(),
        updatedAt: new Date(),
      }));
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await authService.register({
        email: 'Jane@Example.com',
        password: 'Test1234!',
        orgName: 'Acme Inc.',
      });

      // Password must never be stored in plaintext.
      const userCreateArgs = txUserCreate.mock.calls[0][0];
      expect(userCreateArgs.data.passwordHash).not.toBe('Test1234!');
      expect(
        await bcrypt.compare('Test1234!', userCreateArgs.data.passwordHash),
      ).toBe(true);

      // The org creator is always 'owner'.
      expect(userCreateArgs.data.role).toBe(UserRole.owner);
      expect(userCreateArgs.data.orgId).toBe('org_1');
      expect(txOrganizationCreate).toHaveBeenCalledWith({
        data: { name: 'Acme Inc.' },
      });

      expect(result.user.email).toBe('jane@example.com'); // normalized
      expect(result.user.role).toBe(UserRole.owner);
      expect(result.user.orgId).toBe('org_1');
      expect(result.accessToken).toEqual(expect.any(String));
      expect(result.refreshToken).toEqual(expect.any(String));
      expect(prisma.refreshToken.create).toHaveBeenCalledTimes(1);
    });

    it('rejects registration with an existing email WITHOUT starting a transaction', async () => {
      usersService.findByEmail.mockResolvedValue({
        id: 'usr_1',
        email: 'jane@example.com',
        passwordHash: 'hash',
        role: UserRole.owner,
        orgId: 'org_1',
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      await expect(
        authService.register({
          email: 'jane@example.com',
          password: 'Test1234!',
          orgName: 'Acme Inc.',
        }),
      ).rejects.toBeInstanceOf(ConflictException);

      // No org should ever be created for a rejected registration.
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('issues tokens carrying the user\'s existing role/orgId for correct credentials', async () => {
      const passwordHash = await bcrypt.hash('Test1234!', 12);
      usersService.findByEmail.mockResolvedValue({
        id: 'usr_1',
        email: 'jane@example.com',
        passwordHash,
        role: UserRole.admin,
        orgId: 'org_1',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await authService.login({
        email: 'jane@example.com',
        password: 'Test1234!',
      });

      expect(result.accessToken).toEqual(expect.any(String));
      expect(result.user.role).toBe(UserRole.admin);
      expect(result.user.orgId).toBe('org_1');
    });

    it('rejects an unknown email with a generic message', async () => {
      usersService.findByEmail.mockResolvedValue(null);

      await expect(
        authService.login({ email: 'ghost@example.com', password: 'whatever1!' }),
      ).rejects.toThrow('Invalid email or password.');
    });

    it('rejects a wrong password with the SAME generic message as an unknown email', async () => {
      const passwordHash = await bcrypt.hash('Test1234!', 12);
      usersService.findByEmail.mockResolvedValue({
        id: 'usr_1',
        email: 'jane@example.com',
        passwordHash,
        role: UserRole.owner,
        orgId: 'org_1',
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      await expect(
        authService.login({ email: 'jane@example.com', password: 'WrongPassword1!' }),
      ).rejects.toThrow('Invalid email or password.');
    });
  });

  describe('refresh', () => {
    it('rotates a valid token: revokes the old one, issues a new pair carrying role/orgId', async () => {
      prisma.refreshToken.findUnique.mockResolvedValue({
        id: 'rt_1',
        userId: 'usr_1',
        revoked: false,
        expiresAt: new Date(Date.now() + 1000 * 60 * 60), // 1h from now
        user: { id: 'usr_1', email: 'jane@example.com', role: UserRole.editor, orgId: 'org_1' },
      });
      prisma.refreshToken.update.mockResolvedValue({});
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await authService.refresh('some-raw-refresh-token');

      expect(prisma.refreshToken.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'rt_1' },
          data: { revoked: true },
        }),
      );
      expect(result.accessToken).toEqual(expect.any(String));
      expect(result.refreshToken).not.toBe('some-raw-refresh-token');
      expect(result.user.role).toBe(UserRole.editor);
      expect(result.user.orgId).toBe('org_1');
    });

    it('rejects an expired token', async () => {
      prisma.refreshToken.findUnique.mockResolvedValue({
        id: 'rt_1',
        userId: 'usr_1',
        revoked: false,
        expiresAt: new Date(Date.now() - 1000), // already expired
        user: { id: 'usr_1', email: 'jane@example.com', role: UserRole.editor, orgId: 'org_1' },
      });

      await expect(authService.refresh('expired-token')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('on reuse of an already-revoked token, revokes ALL of that user\'s tokens', async () => {
      prisma.refreshToken.findUnique.mockResolvedValue({
        id: 'rt_1',
        userId: 'usr_1',
        revoked: true, // already used once before — reuse attempt
        expiresAt: new Date(Date.now() + 1000 * 60 * 60),
        user: { id: 'usr_1', email: 'jane@example.com', role: UserRole.editor, orgId: 'org_1' },
      });

      await expect(authService.refresh('reused-token')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );

      expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
        where: { userId: 'usr_1', revoked: false },
        data: { revoked: true },
      });
    });

    it('rejects an unrecognized token', async () => {
      prisma.refreshToken.findUnique.mockResolvedValue(null);

      await expect(authService.refresh('unknown-token')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });

  describe('logout', () => {
    it('revokes the matching refresh token', async () => {
      prisma.refreshToken.updateMany.mockResolvedValue({ count: 1 });

      await authService.logout('some-raw-refresh-token');

      expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { revoked: true },
        }),
      );
    });
  });
});
