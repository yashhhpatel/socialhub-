import { CallHandler, ExecutionContext } from '@nestjs/common';
import { firstValueFrom, of, throwError } from 'rxjs';

import { AuditLogInterceptor } from './audit-log.interceptor';

function ctx(req: unknown, statusCode = 200): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => req,
      getResponse: () => ({ statusCode }),
    }),
  } as unknown as ExecutionContext;
}

const handler = (obs: ReturnType<CallHandler['handle']>): CallHandler => ({ handle: () => obs });

function authedReq(method: string, extra: Record<string, unknown> = {}) {
  return {
    method,
    path: '/x',
    route: { path: '/content/assets/:id' },
    params: { id: 'asset_1' },
    user: { userId: 'u1', email: 'a@ex.com', orgId: 'org_1' },
    ...extra,
  };
}

describe('AuditLogInterceptor', () => {
  let interceptor: AuditLogInterceptor;
  let prisma: { auditLog: { create: jest.Mock } };

  beforeEach(() => {
    prisma = { auditLog: { create: jest.fn().mockResolvedValue({}) } };
    interceptor = new AuditLogInterceptor(prisma as never);
  });

  it.each(['POST', 'PATCH', 'PUT', 'DELETE'])(
    'records an authenticated %s with actor, target, method, path and status',
    async (method) => {
      await firstValueFrom(
        interceptor.intercept(ctx(authedReq(method), 201), handler(of('ok'))),
      );

      expect(prisma.auditLog.create).toHaveBeenCalledTimes(1);
      const data = prisma.auditLog.create.mock.calls[0][0].data;
      expect(data).toMatchObject({
        orgId: 'org_1',
        actorId: 'u1',
        actorEmail: 'a@ex.com',
        method,
        path: '/content/assets/:id',
        targetId: 'asset_1',
        statusCode: 201,
      });
    },
  );

  it('does not record a GET (reads are not audited)', async () => {
    await firstValueFrom(interceptor.intercept(ctx(authedReq('GET')), handler(of('ok'))));
    expect(prisma.auditLog.create).not.toHaveBeenCalled();
  });

  it('does not record an unauthenticated mutation (pre-auth routes)', async () => {
    const req = { method: 'POST', path: '/auth/login', params: {} }; // no user
    await firstValueFrom(interceptor.intercept(ctx(req), handler(of('ok'))));
    expect(prisma.auditLog.create).not.toHaveBeenCalled();
  });

  it('records a FAILED mutation with its status, then rethrows', async () => {
    const failing = throwError(() => ({ status: 403, message: 'forbidden' }));
    await expect(
      firstValueFrom(interceptor.intercept(ctx(authedReq('DELETE')), handler(failing))),
    ).rejects.toMatchObject({ status: 403 });

    expect(prisma.auditLog.create).toHaveBeenCalledTimes(1);
    expect(prisma.auditLog.create.mock.calls[0][0].data.statusCode).toBe(403);
  });

  it('never lets an audit-write failure break the request', async () => {
    prisma.auditLog.create.mockRejectedValue(new Error('db down'));
    // The handler still resolves normally despite the audit write failing.
    await expect(
      firstValueFrom(interceptor.intercept(ctx(authedReq('POST')), handler(of('ok')))),
    ).resolves.toBe('ok');
  });
});
