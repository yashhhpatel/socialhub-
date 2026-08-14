import { ConfigService } from '@nestjs/config';

import { VideoProcessingService } from './video-processing.service';

function makeService(): VideoProcessingService {
  // A cloud name so cloudinary.url() produces a stable, assertable host.
  const configService = {
    get: jest.fn((key: string) => (key === 'CLOUDINARY_CLOUD_NAME' ? 'demo' : undefined)),
  } as unknown as ConfigService;
  return new VideoProcessingService(configService);
}

describe('VideoProcessingService', () => {
  describe('buildTransformedVideoUrl', () => {
    it('delivers an mp4 from the video resource, cropped to the platform frame', () => {
      const url = makeService().buildTransformedVideoUrl('socialhub/clip', {
        width: 1080,
        height: 1080,
      });

      expect(url).toContain('/video/upload/');
      expect(url).toContain('c_fill');
      expect(url).toContain('w_1080');
      expect(url).toContain('h_1080');
      // `.mp4` then Cloudinary's analytics query param, so match the segment.
      expect(url).toContain('.mp4');
    });

    it('adds a duration cap when a max is given (the per-platform trim)', () => {
      const url = makeService().buildTransformedVideoUrl('socialhub/clip', {
        width: 1600,
        height: 900,
        maxDurationSeconds: 140,
      });

      // Cloudinary encodes duration as du_<seconds>.
      expect(url).toContain('du_140');
    });

    it('omits the duration cap when no max is given', () => {
      const url = makeService().buildTransformedVideoUrl('socialhub/clip', {
        width: 1080,
        height: 1080,
      });

      expect(url).not.toContain('du_');
    });
  });

  describe('buildPosterUrl', () => {
    it('delivers a jpg still from the video', () => {
      const url = makeService().buildPosterUrl('socialhub/clip');
      expect(url).toContain('/video/upload/');
      expect(url).toContain('.jpg');
    });
  });
});
