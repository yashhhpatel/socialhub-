import { NotFoundException } from '@nestjs/common';

import { CommentsService } from './comments.service';

describe('CommentsService', () => {
  let service: CommentsService;
  let prisma: { comment: { create: jest.Mock; findMany: jest.Mock } };
  let content: { findByIdScoped: jest.Mock };

  beforeEach(() => {
    prisma = {
      comment: {
        create: jest.fn((args) => ({
          id: 'c1',
          ...args.data,
          createdAt: new Date(),
          author: { id: 'u1', email: 'a@ex.com' },
        })),
        findMany: jest.fn().mockResolvedValue([]),
      },
    };
    content = { findByIdScoped: jest.fn().mockResolvedValue({ id: 'asset_1', orgId: 'org_1' }) };
    service = new CommentsService(prisma as never, content as never);
  });

  describe('create', () => {
    it('scopes to the org via the asset before writing, then creates the comment', async () => {
      const c = await service.create('org_1', 'asset_1', 'u1', 'Looks great');

      expect(content.findByIdScoped).toHaveBeenCalledWith('asset_1', 'org_1');
      expect(prisma.comment.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { assetId: 'asset_1', authorId: 'u1', body: 'Looks great' },
        }),
      );
      expect(c.author.email).toBe('a@ex.com');
    });

    it('propagates the 404 when the asset is not in the org', async () => {
      content.findByIdScoped.mockRejectedValue(new NotFoundException());
      await expect(service.create('org_1', 'other', 'u1', 'x')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.comment.create).not.toHaveBeenCalled();
    });
  });

  describe('list', () => {
    it('scopes via the asset and returns the thread oldest-first with authors', async () => {
      await service.list('org_1', 'asset_1');
      expect(content.findByIdScoped).toHaveBeenCalledWith('asset_1', 'org_1');
      const args = prisma.comment.findMany.mock.calls[0][0];
      expect(args.where).toEqual({ assetId: 'asset_1' });
      expect(args.orderBy).toEqual({ createdAt: 'asc' });
      expect(args.include.author.select).toEqual({ id: true, email: true });
    });
  });
});
