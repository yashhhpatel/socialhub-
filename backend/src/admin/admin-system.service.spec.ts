import { ConfigService } from '@nestjs/config';
import { Queue } from 'bullmq';

import { PrismaService } from '../prisma/prisma.service';
import { AdminSystemService } from './admin-system.service';

function fakeQueue(counts: Record<string, number>): Queue {
  return {
    getJobCounts: jest.fn().mockResolvedValue(counts),
  } as unknown as Queue;
}

describe('AdminSystemService', () => {
  let service: AdminSystemService;
  let prisma: { $queryRaw: jest.Mock; auditLog: { findMany: jest.Mock } };
  let config: { get: jest.Mock };

  beforeEach(() => {
    prisma = {
      $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
      auditLog: { findMany: jest.fn().mockResolvedValue([]) },
    };
    config = { get: jest.fn().mockReturnValue(undefined) };
    const q = () => fakeQueue({ waiting: 1, active: 0, completed: 5, failed: 2, delayed: 0 });
    service = new AdminSystemService(
      prisma as unknown as PrismaService,
      config as unknown as ConfigService,
      q(), q(), q(), q(), q(), q(),
    );
  });

  it('reports healthy db + redis and process uptime', async () => {
    const h = await service.health();
    expect(h.db).toBe(true);
    expect(h.redis).toBe(true);
    expect(h.uptimeSeconds).toBeGreaterThanOrEqual(0);
    expect(h.sentryConfigured).toBe(false);
  });

  it('reports db down when the query throws', async () => {
    prisma.$queryRaw.mockRejectedValue(new Error('no db'));
    const h = await service.health();
    expect(h.db).toBe(false);
  });

  it('returns one stat row per queue', async () => {
    const stats = await service.queues_();
    expect(stats).toHaveLength(6);
    expect(stats[0]).toEqual(
      expect.objectContaining({ waiting: 1, completed: 5, failed: 2 }),
    );
  });

  it('recentErrors queries statusCode >= 400, newest first', async () => {
    await service.recentErrors();
    const args = prisma.auditLog.findMany.mock.calls[0][0];
    expect(args.where.statusCode.gte).toBe(400);
    expect(args.orderBy).toEqual({ createdAt: 'desc' });
  });
});
