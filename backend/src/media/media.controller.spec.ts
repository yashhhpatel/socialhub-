import { BadRequestException } from '@nestjs/common';

import { CloudinaryService } from './cloudinary.service';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';
import { VideoProcessingService } from './video-processing.service';

describe('MediaController', () => {
  let controller: MediaController;
  let media: { record: jest.Mock; listForOrg: jest.Mock; remove: jest.Mock };
  let cloudinary: { uploadImage: jest.Mock };
  let video: { uploadVideo: jest.Mock; buildPosterUrl: jest.Mock };

  const req = {
    user: { userId: 'u1', email: 'e', role: 'editor', orgId: 'org1' },
  } as never;

  beforeEach(() => {
    media = {
      record: jest.fn(),
      listForOrg: jest.fn().mockResolvedValue([]),
      remove: jest.fn(),
    };
    cloudinary = { uploadImage: jest.fn() };
    video = { uploadVideo: jest.fn(), buildPosterUrl: jest.fn() };
    controller = new MediaController(
      media as unknown as MediaService,
      cloudinary as unknown as CloudinaryService,
      video as unknown as VideoProcessingService,
    );
  });

  it('lists the org library as DTOs', async () => {
    media.listForOrg.mockResolvedValue([
      {
        id: 'm1',
        orgId: 'org1',
        url: 'u',
        publicId: 'p',
        type: 'image',
        name: 'n.png',
        posterUrl: null,
        createdById: 'u1',
        createdAt: new Date(0),
      },
    ]);
    const out = await controller.list(req);
    expect(out).toHaveLength(1);
    expect(out[0]).not.toHaveProperty('createdById');
    expect(out[0].id).toBe('m1');
  });

  it('uploads an image via Cloudinary and persists it', async () => {
    cloudinary.uploadImage.mockResolvedValue({ url: 'cdn/x.png', publicId: 'x' });
    media.record.mockResolvedValue({
      id: 'm1',
      url: 'cdn/x.png',
      publicId: 'x',
      type: 'image',
      name: 'x.png',
      posterUrl: null,
      createdAt: new Date(0),
    });
    const file = {
      mimetype: 'image/png',
      originalname: 'x.png',
      buffer: Buffer.from(''),
    } as Express.Multer.File;

    const out = await controller.upload(req, file);

    expect(cloudinary.uploadImage).toHaveBeenCalled();
    expect(video.uploadVideo).not.toHaveBeenCalled();
    expect(media.record).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'image', orgId: 'org1', createdById: 'u1' }),
    );
    expect(out.id).toBe('m1');
  });

  it('uploads a video through the video pipeline with a poster', async () => {
    video.uploadVideo.mockResolvedValue({ url: 'cdn/v.mp4', publicId: 'v' });
    video.buildPosterUrl.mockReturnValue('cdn/v.jpg');
    media.record.mockResolvedValue({
      id: 'm2',
      url: 'cdn/v.mp4',
      publicId: 'v',
      type: 'video',
      name: 'v.mp4',
      posterUrl: 'cdn/v.jpg',
      createdAt: new Date(0),
    });
    const file = {
      mimetype: 'video/mp4',
      originalname: 'v.mp4',
      buffer: Buffer.from(''),
    } as Express.Multer.File;

    await controller.upload(req, file);

    expect(video.uploadVideo).toHaveBeenCalled();
    expect(cloudinary.uploadImage).not.toHaveBeenCalled();
    expect(media.record).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'video', posterUrl: 'cdn/v.jpg' }),
    );
  });

  it('rejects when no file is provided', async () => {
    await expect(
      controller.upload(req, undefined as unknown as Express.Multer.File),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('delegates delete to the service, org-scoped', async () => {
    media.remove.mockResolvedValue(undefined);
    await controller.remove(req, 'm1');
    expect(media.remove).toHaveBeenCalledWith('m1', 'org1');
  });
});
