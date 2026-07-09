import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcryptjs';

import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let authService: AuthService;
  let usersService: jest.Mocked<Pick<UsersService, 'findByEmail' | 'create'>>;
  let prisma: {
    refreshToken: {
      findUnique: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      updateMany: jest.Mock;
    };
  };

  beforeEach(async () => {
    usersService = {
      findByEmail: jest.fn(),
      create: jest.fn(),
    };

    prisma = {
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
    it('hashes the password and issues a token pair for a new user', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      usersService.create.mockImplementation(async (params) => ({
        id: 'usr_1',
        email: params.email.trim().toLowerCase(), // mirrors UsersService.create's real normalization
        passwordHash: params.passwordHash,
        createdAt: new Date(),
        updatedAt: new Date(),
      }));
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await authService.register({
        email: 'Jane@Example.com',
        password: 'Test1234!',
      });

      // Password must never be stored in plaintext.
      const createCall = usersService.create.mock.calls[0][0];
      expect(createCall.passwordHash).not.toBe('Test1234!');
      expect(
        await bcrypt.compare('Test1234!', createCall.passwordHash),
      ).toBe(true);

      expect(result.user.email).toBe('jane@example.com'); // normalized in UsersService.create
      expect(result.accessToken).toEqual(expect.any(String));
      expect(result.refreshToken).toEqual(expect.any(String));
      expect(prisma.refreshToken.create).toHaveBeenCalledTimes(1);
    });

    it('rejects registration with an existing email', async () => {
      usersService.findByEmail.mockResolvedValue({
        id: 'usr_1',
        email: 'jane@example.com',
        passwordHash: 'hash',
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      await expect(
        authService.register({ email: 'jane@example.com', password: 'Test1234!' }),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });

  describe('login', () => {
    it('issues tokens for correct credentials', async () => {
      const passwordHash = await bcrypt.hash('Test1234!', 12);
      usersService.findByEmail.mockResolvedValue({
        id: 'usr_1',
        email: 'jane@example.com',
        passwordHash,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      prisma.refreshToken.create.mockResolvedValue({});

      const result = await authService.login({
        email: 'jane@example.com',
        password: 'Test1234!',
      });

      expect(result.accessToken).toEqual(expect.any(String));
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
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      await expect(
        authService.login({ email: 'jane@example.com', password: 'WrongPassword1!' }),
      ).rejects.toThrow('Invalid email or password.');
    });
  });

  describe('refresh', () => {
    it('rotates a valid token: revokes the old one, issues a new pair', async () => {
      prisma.refreshToken.findUnique.mockResolvedValue({
        id: 'rt_1',
        userId: 'usr_1',
        revoked: false,
        expiresAt: new Date(Date.now() + 1000 * 60 * 60), // 1h from now
        user: { id: 'usr_1', email: 'jane@example.com' },
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
    });

    it('rejects an expired token', async () => {
      prisma.refreshToken.findUnique.mockResolvedValue({
        id: 'rt_1',
        userId: 'usr_1',
        revoked: false,
        expiresAt: new Date(Date.now() - 1000), // already expired
        user: { id: 'usr_1', email: 'jane@example.com' },
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
        user: { id: 'usr_1', email: 'jane@example.com' },
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
