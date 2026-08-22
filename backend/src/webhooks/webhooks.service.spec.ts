import { Platform, PublishJobStatus, SocialAccountStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { WebhooksService } from './webhooks.service';

describe('WebhooksService', () => {
  let service: WebhooksService;
  let prisma: {
    publishJob: { updateMany: jest.Mock };
    socialAccount: { updateMany: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      publishJob: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      socialAccount: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
    service = new WebhooksService(prisma as unknown as PrismaService);
  });

  it('marks the PublishJob failed when a published post is removed on the platform', async () => {
    const res = await service.handleMetaEvent(Platform.instagram, {
      object: 'instagram',
      entry: [
        {
          id: 'user_1',
          changes: [
            { field: 'feed', value: { verb: 'remove', post_id: 'post_123' } },
          ],
        },
      ],
    });

    expect(res.handled).toBe(1);
    expect(prisma.publishJob.updateMany).toHaveBeenCalledWith({
      where: {
        externalPostId: 'post_123',
        status: PublishJobStatus.published,
        socialAccount: { platform: Platform.instagram },
      },
      data: {
        status: PublishJobStatus.failed,
        lastError: expect.stringContaining('removed'),
      },
    });
  });

  it('marks the account revoked on a permission removal', async () => {
    const res = await service.handleMetaEvent(Platform.facebook, {
      entry: [
        {
          id: 'page_9',
          changes: [{ field: 'permissions', value: { verb: 'revoke' } }],
        },
      ],
    });

    expect(res.handled).toBe(1);
    expect(prisma.socialAccount.updateMany).toHaveBeenCalledWith({
      where: {
        platform: Platform.facebook,
        externalUserId: 'page_9',
        status: { not: SocialAccountStatus.revoked },
      },
      data: { status: SocialAccountStatus.revoked },
    });
  });

  it('is idempotent: a re-delivered event that changes nothing reports handled=0', async () => {
    prisma.publishJob.updateMany.mockResolvedValue({ count: 0 }); // already failed
    const res = await service.handleMetaEvent(Platform.threads, {
      entry: [
        {
          id: 'u',
          changes: [{ field: 'feed', value: { verb: 'delete', post_id: 'p1' } }],
        },
      ],
    });
    expect(res.handled).toBe(0);
  });

  it('ignores unmapped events safely (no writes, handled=0)', async () => {
    const res = await service.handleMetaEvent(Platform.instagram, {
      entry: [
        {
          id: 'u',
          changes: [{ field: 'comments', value: { verb: 'add', id: 'c1' } }],
        },
      ],
    });
    expect(res.handled).toBe(0);
    expect(prisma.publishJob.updateMany).not.toHaveBeenCalled();
    expect(prisma.socialAccount.updateMany).not.toHaveBeenCalled();
  });

  it('handles an empty / entry-less payload without error', async () => {
    await expect(service.handleMetaEvent(Platform.instagram, {})).resolves.toEqual({
      handled: 0,
    });
  });
});
