import { PrismaService } from '../prisma/prisma.service';
import { AdminAuditService } from './admin-audit.service';

describe('AdminAuditService', () => {
  let service: AdminAuditService;
  let prisma: { auditLog: { count: jest.Mock; findMany: jest.Mock } };

  beforeEach(() => {
    prisma = { auditLog: { count: jest.fn().mockResolvedValue(0), findMany: jest.fn().mockResolvedValue([]) } };
    service = new AdminAuditService(prisma as unknown as PrismaService);
  });

  it('queries cross-org with no filters by default', async () => {
    await service.list({});
    expect(prisma.auditLog.findMany.mock.calls[0][0].where).toEqual({});
  });

  it('applies org/actor/method filters (normalized)', async () => {
    await service.list({ orgId: ' o1 ', actorEmail: ' A@B ', method: 'post' });
    const where = prisma.auditLog.findMany.mock.calls[0][0].where;
    expect(where.orgId).toBe('o1');
    expect(where.actorEmail.contains).toBe('a@b');
    expect(where.method).toBe('POST');
  });

  it('clamps the limit', async () => {
    const res = await service.list({ limit: 9999, page: 3 });
    expect(res.limit).toBe(100);
    expect(prisma.auditLog.findMany.mock.calls[0][0].skip).toBe(200);
  });
});
