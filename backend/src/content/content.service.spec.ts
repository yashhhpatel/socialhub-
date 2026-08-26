import { NotFoundException } from '@nestjs/common';

import { ContentService } from './content.service';

describe('ContentService', () => {
  let service: ContentService;
  let prisma: {
    contentAsset: {
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
  };

  beforeEach(() => {
    prisma = {
      contentAsset: {
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
    };
    service = new ContentService(prisma as never);
  });

  describe('create', () => {
    it('creates an asset scoped to the given org and creator', async () => {
      prisma.contentAsset.create.mockResolvedValue({ id: 'asset_1' });

      await service.create('org_1', 'usr_1', {
        type: 'image',
        canvasJson: { width: 1080, height: 1080, layers: [] },
      });

      expect(prisma.contentAsset.create).toHaveBeenCalledWith({
        data: {
          orgId: 'org_1',
          createdById: 'usr_1',
          type: 'image',
          canvasJson: { width: 1080, height: 1080, layers: [] },
        },
      });
    });
  });

  describe('delete', () => {
    it('deletes an asset the org owns', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({
        id: 'asset_1',
        orgId: 'org_1',
      });
      prisma.contentAsset.delete.mockResolvedValue({});

      await service.delete('asset_1', 'org_1');

      expect(prisma.contentAsset.delete).toHaveBeenCalledWith({
        where: { id: 'asset_1' },
      });
    });

    it("404s (and never deletes) another org's asset", async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({
        id: 'asset_1',
        orgId: 'other_org',
      });

      await expect(service.delete('asset_1', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.contentAsset.delete).not.toHaveBeenCalled();
    });

    it('404s a missing asset', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue(null);
      await expect(service.delete('missing', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.contentAsset.delete).not.toHaveBeenCalled();
    });
  });

  describe('findByIdScoped', () => {
    it('returns the asset when it belongs to the given org', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({ id: 'asset_1', orgId: 'org_1' });

      const result = await service.findByIdScoped('asset_1', 'org_1');

      expect(result.id).toBe('asset_1');
    });

    it('throws NotFoundException (not a permission error) for a cross-org asset', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({
        id: 'asset_1',
        orgId: 'some_other_org',
      });

      await expect(service.findByIdScoped('asset_1', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('throws NotFoundException when the asset does not exist at all', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue(null);

      await expect(service.findByIdScoped('missing', 'org_1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('findByIdScopedWithVariants', () => {
    it('includes variants, which the documented 202 polling flow depends on', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({
        id: 'asset_1',
        orgId: 'org_1',
        variants: [{ id: 'var_1', platform: 'instagram' }],
      });

      const result = await service.findByIdScopedWithVariants('asset_1', 'org_1');

      expect(prisma.contentAsset.findUnique).toHaveBeenCalledWith({
        where: { id: 'asset_1' },
        include: { variants: { orderBy: { platform: 'asc' } } },
      });
      expect(result.variants).toHaveLength(1);
    });

    it('applies the same cross-org 404 rule as findByIdScoped', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({
        id: 'asset_1',
        orgId: 'some_other_org',
        variants: [],
      });

      await expect(
        service.findByIdScopedWithVariants('asset_1', 'org_1'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('update', () => {
    it('checks ownership before updating, and persists the new canvasJson', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({ id: 'asset_1', orgId: 'org_1' });
      prisma.contentAsset.update.mockResolvedValue({ id: 'asset_1' });

      await service.update('asset_1', 'org_1', {
        canvasJson: { width: 1080, height: 1350, layers: [{ type: 'text' }] },
      });

      expect(prisma.contentAsset.update).toHaveBeenCalledWith({
        where: { id: 'asset_1' },
        data: { canvasJson: { width: 1080, height: 1350, layers: [{ type: 'text' }] } },
      });
    });

    it('rejects an update to a cross-org asset WITHOUT calling prisma.update at all', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({
        id: 'asset_1',
        orgId: 'some_other_org',
      });

      await expect(
        service.update('asset_1', 'org_1', { canvasJson: { width: 1, height: 1, layers: [] } }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.contentAsset.update).not.toHaveBeenCalled();
    });

    it('omits canvasJson from the update payload entirely when not provided (true partial update)', async () => {
      prisma.contentAsset.findUnique.mockResolvedValue({ id: 'asset_1', orgId: 'org_1' });
      prisma.contentAsset.update.mockResolvedValue({ id: 'asset_1' });

      await service.update('asset_1', 'org_1', {});

      expect(prisma.contentAsset.update).toHaveBeenCalledWith({
        where: { id: 'asset_1' },
        data: {},
      });
    });
  });
});
