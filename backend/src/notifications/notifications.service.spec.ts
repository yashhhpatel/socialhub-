import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from './notifications.service';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let prisma: {
    notification: {
      create: jest.Mock;
      findMany: jest.Mock;
      count: jest.Mock;
      updateMany: jest.Mock;
    };
  };

  beforeEach(() => {
    prisma = {
      notification: {
        create: jest.fn().mockResolvedValue({ id: 'n1' }),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(3),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    service = new NotificationsService(prisma as unknown as PrismaService);
  });

  it('creates a notification with the given fields', async () => {
    await service.create({
      userId: 'u1',
      type: 'publish_succeeded',
      title: 'Post published',
      body: 'Your post was published.',
      linkPath: '/calendar',
    });
    expect(prisma.notification.create).toHaveBeenCalledWith({
      data: {
        userId: 'u1',
        type: 'publish_succeeded',
        title: 'Post published',
        body: 'Your post was published.',
        linkPath: '/calendar',
      },
    });
  });

  it('notifySafe swallows errors (never breaks the caller)', async () => {
    prisma.notification.create.mockRejectedValue(new Error('db down'));
    await expect(
      service.notifySafe({
        userId: 'u1',
        type: 'publish_failed',
        title: 'x',
        body: 'y',
      }),
    ).resolves.toBeUndefined();
  });

  it('lists a user\'s notifications newest-first, capped', async () => {
    await service.listForUser('u1', 10);
    expect(prisma.notification.findMany).toHaveBeenCalledWith({
      where: { userId: 'u1' },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });
  });

  it('counts only unread', async () => {
    await expect(service.unreadCount('u1')).resolves.toBe(3);
    expect(prisma.notification.count).toHaveBeenCalledWith({
      where: { userId: 'u1', readAt: null },
    });
  });

  it('markRead is scoped to the owner and only touches unread rows', async () => {
    await service.markRead('n1', 'u1');
    expect(prisma.notification.updateMany).toHaveBeenCalledWith({
      where: { id: 'n1', userId: 'u1', readAt: null },
      data: { readAt: expect.any(Date) },
    });
  });

  it('markAllRead flips every unread row for the user', async () => {
    await service.markAllRead('u1');
    expect(prisma.notification.updateMany).toHaveBeenCalledWith({
      where: { userId: 'u1', readAt: null },
      data: { readAt: expect.any(Date) },
    });
  });
});
