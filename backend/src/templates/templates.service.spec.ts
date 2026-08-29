import { NotFoundException } from '@nestjs/common';

import { TemplatesService } from './templates.service';

describe('TemplatesService', () => {
  let service: TemplatesService;
  let prisma: {
    template: {
      findMany: jest.Mock;
      findUnique: jest.Mock;
      create: jest.Mock;
      delete: jest.Mock;
    };
  };

  const canvasJson = { width: 1080, height: 1080, layers: [] };

  beforeEach(() => {
    prisma = {
      template: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn(),
        create: jest.fn((args) => ({ id: 'tpl_1', ...args.data })),
        delete: jest.fn().mockResolvedValue(undefined),
      },
    };
    service = new TemplatesService(prisma as never);
  });

  describe('list', () => {
    it('is org-scoped, newest first, and excludes canvasJson from the row', async () => {
      await service.list('org_1');

      const args = prisma.template.findMany.mock.calls[0][0];
      expect(args.where).toEqual({ orgId: 'org_1' });
      expect(args.orderBy).toEqual({ createdAt: 'desc' });
      // canvasJson must NOT be selected for the gallery payload.
      expect(args.select.canvasJson).toBeUndefined();
      expect(args.select.name).toBe(true);
    });
  });

  describe('findByIdScoped', () => {
    it('returns the template when it belongs to the org', async () => {
      prisma.template.findUnique.mockResolvedValue({ id: 'tpl_1', orgId: 'org_1', canvasJson });
      const t = await service.findByIdScoped('tpl_1', 'org_1');
      expect(t.id).toBe('tpl_1');
    });

    it('404s for a template that belongs to another org', async () => {
      prisma.template.findUnique.mockResolvedValue({ id: 'tpl_1', orgId: 'other_org' });
      await expect(service.findByIdScoped('tpl_1', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('404s for a template that does not exist', async () => {
      prisma.template.findUnique.mockResolvedValue(null);
      await expect(service.findByIdScoped('missing', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('create', () => {
    it('persists the template under the org with its canvas payload', async () => {
      await service.create('org_1', {
        name: 'Promo square',
        category: 'Promotions',
        canvasJson: canvasJson as never,
        thumbnailUrl: 'https://cdn.test/thumb.png',
      });

      const args = prisma.template.create.mock.calls[0][0];
      expect(args.data.orgId).toBe('org_1');
      expect(args.data.name).toBe('Promo square');
      expect(args.data.category).toBe('Promotions');
      expect(args.data.canvasJson).toEqual(canvasJson);
    });

    it('defaults optional category/thumbnail to null', async () => {
      await service.create('org_1', { name: 'Bare', canvasJson: canvasJson as never });

      const args = prisma.template.create.mock.calls[0][0];
      expect(args.data.category).toBeNull();
      expect(args.data.thumbnailUrl).toBeNull();
    });
  });

  describe('delete', () => {
    it('deletes a template the org owns', async () => {
      prisma.template.findUnique.mockResolvedValue({ id: 'tpl_1', orgId: 'org_1' });

      await service.delete('tpl_1', 'org_1');

      expect(prisma.template.delete).toHaveBeenCalledWith({
        where: { id: 'tpl_1' },
      });
    });

    it('404s and deletes nothing for another org\'s template', async () => {
      prisma.template.findUnique.mockResolvedValue({ id: 'tpl_1', orgId: 'other' });

      await expect(service.delete('tpl_1', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.template.delete).not.toHaveBeenCalled();
    });
  });
});
