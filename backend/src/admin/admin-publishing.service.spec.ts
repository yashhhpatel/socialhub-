import { PrismaService } from '../prisma/prisma.service';
import { PublishingService } from '../publishing/publishing.service';
import { AdminPublishingService } from './admin-publishing.service';

describe('AdminPublishingService', () => {
  let service: AdminPublishingService;
  let prisma: { publishJob: { count: jest.Mock; findMany: jest.Mock } };
  let publishing: { requeueJob: jest.Mock; cancelJob: jest.Mock };

  beforeEach(() => {
    prisma = { publishJob: { count: jest.fn(), findMany: jest.fn() } };
    publishing = {
      requeueJob: jest.fn().mockResolvedValue(undefined),
      cancelJob: jest.fn().mockResolvedValue(undefined),
    };
    service = new AdminPublishingService(
      prisma as unknown as PrismaService,
      publishing as unknown as PublishingService,
    );
  });

  it('lists jobs across orgs and flattens the account relation', async () => {
    prisma.publishJob.count.mockResolvedValue(1);
    prisma.publishJob.findMany.mockResolvedValue([
      {
        id: 'j1',
        status: 'failed',
        attemptCount: 3,
        lastError: 'rate limited',
        scheduledAt: null,
        externalPostId: null,
        createdAt: new Date(0),
        socialAccount: {
          platform: 'x',
          externalAccountId: 'ext',
          orgId: 'o1',
          organization: { name: 'Acme' },
        },
      },
    ]);

    const res = await service.list({ status: 'failed' });

    expect(prisma.publishJob.findMany.mock.calls[0][0].where.status).toBe('failed');
    expect(res.data[0]).toEqual(
      expect.objectContaining({
        orgName: 'Acme',
        platform: 'x',
        lastError: 'rate limited',
      }),
    );
  });

  it('ignores an invalid status filter', async () => {
    prisma.publishJob.count.mockResolvedValue(0);
    prisma.publishJob.findMany.mockResolvedValue([]);
    await service.list({ status: 'nonsense' });
    expect(prisma.publishJob.findMany.mock.calls[0][0].where.status).toBeUndefined();
  });

  it('delegates retry and cancel to PublishingService', async () => {
    await service.retry('j1');
    await service.cancel('j2');
    expect(publishing.requeueJob).toHaveBeenCalledWith('j1');
    expect(publishing.cancelJob).toHaveBeenCalledWith('j2');
  });
});
