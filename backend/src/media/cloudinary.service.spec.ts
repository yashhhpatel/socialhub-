import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary } from 'cloudinary';
import { PassThrough } from 'stream';

import { CloudinaryService } from './cloudinary.service';

jest.mock('cloudinary', () => ({
  v2: {
    config: jest.fn(),
    uploader: {
      upload_stream: jest.fn(),
    },
  },
}));

function makeFile(overrides: Partial<Express.Multer.File> = {}): Express.Multer.File {
  return {
    buffer: Buffer.from('fake image bytes'),
    mimetype: 'image/jpeg',
    originalname: 'test.jpg',
    ...overrides,
  } as Express.Multer.File;
}

describe('CloudinaryService', () => {
  const mockUploadStream = cloudinary.uploader.upload_stream as jest.Mock;
  let service: CloudinaryService;

  beforeEach(() => {
    jest.clearAllMocks();

    const configService = {
      get: jest.fn((key: string) => `mock-${key}`),
    } as unknown as ConfigService;

    service = new CloudinaryService(configService);
  });

  it('configures the Cloudinary SDK from ConfigService at construction', () => {
    expect(cloudinary.config).toHaveBeenCalledWith({
      cloud_name: 'mock-CLOUDINARY_CLOUD_NAME',
      api_key: 'mock-CLOUDINARY_API_KEY',
      api_secret: 'mock-CLOUDINARY_API_SECRET',
    });
  });

  it('resolves with the hosted secure_url and public_id on a successful upload', async () => {
    mockUploadStream.mockImplementation((options, callback) => {
      const stream = new PassThrough();
      process.nextTick(() =>
        callback(null, {
          secure_url: 'https://res.cloudinary.com/demo/image/upload/v1/socialhub/abc.jpg',
          public_id: 'socialhub/abc',
        }),
      );
      return stream;
    });

    const result = await service.uploadImage(makeFile());

    expect(result.url).toBe(
      'https://res.cloudinary.com/demo/image/upload/v1/socialhub/abc.jpg',
    );
    expect(result.publicId).toBe('socialhub/abc');
  });

  it('defaults to the "socialhub" folder, and passes a custom folder when given', async () => {
    mockUploadStream.mockImplementation((options, callback) => {
      const stream = new PassThrough();
      process.nextTick(() => callback(null, { secure_url: 'url', public_id: 'id' }));
      return stream;
    });

    await service.uploadImage(makeFile());
    expect(mockUploadStream).toHaveBeenCalledWith(
      expect.objectContaining({ folder: 'socialhub', resource_type: 'image' }),
      expect.any(Function),
    );

    await service.uploadImage(makeFile(), 'custom-folder');
    expect(mockUploadStream).toHaveBeenLastCalledWith(
      expect.objectContaining({ folder: 'custom-folder' }),
      expect.any(Function),
    );
  });

  it('rejects when Cloudinary reports an error', async () => {
    mockUploadStream.mockImplementation((options, callback) => {
      const stream = new PassThrough();
      process.nextTick(() => callback(new Error('Cloudinary rejected the upload'), undefined));
      return stream;
    });

    await expect(service.uploadImage(makeFile())).rejects.toThrow(
      'Cloudinary rejected the upload',
    );
  });

  it('rejects with a clear error if Cloudinary returns neither an error nor a result', async () => {
    mockUploadStream.mockImplementation((options, callback) => {
      const stream = new PassThrough();
      process.nextTick(() => callback(undefined, undefined));
      return stream;
    });

    await expect(service.uploadImage(makeFile())).rejects.toThrow(/no result/i);
  });
});
