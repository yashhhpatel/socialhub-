import { AuditService } from './audit.service';

describe('AuditService', () => {
  let service: AuditService;
  let prisma: { auditLog: { findMany: jest.Mock } };

  beforeEach(() => {
    prisma = { auditLog: { findMany: jest.fn().mockResolvedValue([]) } };
    service = new AuditService(prisma as never);
  });

  it('always scopes to the org, newest first', async () => {
    await service.list('org_1', {});
    const args = prisma.auditLog.findMany.mock.calls[0][0];
    expect(args.where).toEqual({ orgId: 'org_1' });
    expect(args.orderBy).toEqual({ createdAt: 'desc' });
    expect(args.take).toBe(100);
  });

  it('applies method + actor + date filters', async () => {
    await service.list('org_1', {
      method: 'DELETE',
      actorEmail: 'a@ex.com',
      from: '2026-08-01T00:00:00.000Z',
      to: '2026-08-14T00:00:00.000Z',
      limit: 50,
    });
    const args = prisma.auditLog.findMany.mock.calls[0][0];
    expect(args.where.method).toBe('DELETE');
    expect(args.where.actorEmail).toBe('a@ex.com');
    expect(args.where.createdAt.gte).toEqual(new Date('2026-08-01T00:00:00.000Z'));
    expect(args.where.createdAt.lte).toEqual(new Date('2026-08-14T00:00:00.000Z'));
    expect(args.take).toBe(50);
  });
});
