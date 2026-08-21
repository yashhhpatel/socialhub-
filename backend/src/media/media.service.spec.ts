import { NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { MediaService } from './media.service';

describe('MediaService', () => {
  let service: MediaService;
  let prisma: {
    mediaAsset: {
      create: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      delete: jest.Mock;
    };
  };

  beforeEach(() => {
    prisma = {
      mediaAsset: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        delete: jest.fn(),
      },
    };
    service = new MediaService(prisma as unknown as PrismaService);
  });

  it('records an image with no poster', async () => {
    prisma.mediaAsset.create.mockResolvedValue({ id: 'm1' });
    await service.record({
      orgId: 'org1',
      createdById: 'u1',
      url: 'https://cdn/x.png',
      publicId: 'x',
      type: 'image',
      name: 'x.png',
    });
    expect(prisma.mediaAsset.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orgId: 'org1',
        type: 'image',
        posterUrl: null,
      }),
    });
  });

  it('lists an org newest first', async () => {
    prisma.mediaAsset.findMany.mockResolvedValue([]);
    await service.listForOrg('org1');
    expect(prisma.mediaAsset.findMany).toHaveBeenCalledWith({
      where: { orgId: 'org1' },
      orderBy: { createdAt: 'desc' },
    });
  });

  it('deletes an asset that belongs to the org', async () => {
    prisma.mediaAsset.findUnique.mockResolvedValue({ id: 'm1', orgId: 'org1' });
    prisma.mediaAsset.delete.mockResolvedValue({});
    await service.remove('m1', 'org1');
    expect(prisma.mediaAsset.delete).toHaveBeenCalledWith({ where: { id: 'm1' } });
  });

  it('refuses to delete another org\'s asset', async () => {
    prisma.mediaAsset.findUnique.mockResolvedValue({ id: 'm1', orgId: 'other' });
    await expect(service.remove('m1', 'org1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(prisma.mediaAsset.delete).not.toHaveBeenCalled();
  });

  it('404s when the asset is missing', async () => {
    prisma.mediaAsset.findUnique.mockResolvedValue(null);
    await expect(service.remove('nope', 'org1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
