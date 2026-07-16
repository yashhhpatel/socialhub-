import { NotFoundException } from '@nestjs/common';

import { ContentService } from './content.service';

describe('ContentService', () => {
  let service: ContentService;
  let prisma: {
    contentAsset: { create: jest.Mock; findUnique: jest.Mock; update: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      contentAsset: {
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
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
