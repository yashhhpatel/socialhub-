import { NotFoundException } from '@nestjs/common';

import { TemplatesService } from './templates.service';

/**
 * Marketplace behaviour on TemplatesService (Milestone 14.1) — publish,
 * search, and especially clone-on-use, where the key guarantee is that the
 * cloned copy is independent of its source (no shared state between orgs).
 */
describe('TemplatesService — marketplace', () => {
  let service: TemplatesService;
  let prisma: {
    template: { findUnique: jest.Mock; findMany: jest.Mock; update: jest.Mock; create: jest.Mock };
  };

  const publicSource = {
    id: 'tpl_src',
    orgId: 'org_author',
    name: 'Promo square',
    category: 'Promotions',
    thumbnailUrl: 'https://cdn.test/t.png',
    canvasJson: { width: 1080, height: 1080, layers: [{ type: 'text', id: 'l1' }] },
    isPublic: true,
    publishedById: 'u_author',
  };

  beforeEach(() => {
    prisma = {
      template: {
        findUnique: jest.fn(),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn((args) => ({ ...publicSource, ...args.data })),
        create: jest.fn((args) => ({ id: 'tpl_clone', ...args.data })),
      },
    };
    service = new TemplatesService(prisma as never);
  });

  describe('publish', () => {
    it("marks the org's own template public and records who published it", async () => {
      prisma.template.findUnique.mockResolvedValue({ ...publicSource, orgId: 'org_1', isPublic: false });
      await service.publish('org_1', 'tpl_src', 'u_1');
      expect(prisma.template.update).toHaveBeenCalledWith({
        where: { id: 'tpl_src' },
        data: { isPublic: true, publishedById: 'u_1' },
      });
    });

    it("404s when publishing another org's template", async () => {
      prisma.template.findUnique.mockResolvedValue({ ...publicSource, orgId: 'other' });
      await expect(service.publish('org_1', 'tpl_src', 'u_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.template.update).not.toHaveBeenCalled();
    });
  });

  describe('searchMarketplace', () => {
    it('lists only public templates, filtered by search + category', async () => {
      await service.searchMarketplace({ search: 'promo', category: 'Promotions' });
      const args = prisma.template.findMany.mock.calls[0][0];
      expect(args.where.isPublic).toBe(true);
      expect(args.where.category).toBe('Promotions');
      expect(args.where.name).toEqual({ contains: 'promo', mode: 'insensitive' });
      // canvasJson is never returned in the listing.
      expect(args.select.canvasJson).toBeUndefined();
    });

    it('omits the name/category filters when not provided', async () => {
      await service.searchMarketplace({});
      const args = prisma.template.findMany.mock.calls[0][0];
      expect(args.where).toEqual({ isPublic: true });
    });
  });

  describe('clone (clone-on-use)', () => {
    it('creates an INDEPENDENT private copy in the cloning org', async () => {
      prisma.template.findUnique.mockResolvedValue(publicSource);

      await service.clone('org_1', 'tpl_src');

      const data = prisma.template.create.mock.calls[0][0].data;
      expect(data.orgId).toBe('org_1'); // owned by the cloner, not the author
      expect(data.isPublic).toBe(false); // a clone is never itself published
      expect(data.publishedById).toBeNull();
      expect(data.name).toBe('Promo square');
      // The canvas is copied by value; mutating the clone's canvas must not
      // touch the source object.
      expect(data.canvasJson).toEqual(publicSource.canvasJson);
      (data.canvasJson as { layers: unknown[] }).layers.push({ type: 'shape' });
      expect((publicSource.canvasJson.layers as unknown[]).length).toBe(1);
    });

    it('refuses to clone a non-public template', async () => {
      prisma.template.findUnique.mockResolvedValue({ ...publicSource, isPublic: false });
      await expect(service.clone('org_1', 'tpl_src')).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.template.create).not.toHaveBeenCalled();
    });

    it('404s a template that does not exist', async () => {
      prisma.template.findUnique.mockResolvedValue(null);
      await expect(service.clone('org_1', 'missing')).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
