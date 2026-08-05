import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary } from 'cloudinary';
import * as streamifier from 'streamifier';

export interface CloudinaryUploadResult {
  url: string;
  publicId: string;
}

/**
 * Verified current (2026) Cloudinary Node.js SDK usage before writing
 * this — v2 API, Multer's in-memory buffer piped through `streamifier`
 * into `cloudinary.uploader.upload_stream`, wrapped in a Promise. This
 * pattern is unchanged from Cloudinary's own current documentation.
 *
 * SCOPE NOTE: config values read via `configService.get()` (not
 * `getOrThrow()`) in the constructor, and CLOUDINARY_* is NOT added to
 * env.validation.ts's required boot schema — same reasoning as the
 * Instagram/X OAuth credentials in Milestones 2.2/2.3: media upload is
 * an optional feature a dev may not have Cloudinary credentials for yet,
 * and the rest of the app has no reason to refuse to boot over it. An
 * actual upload attempt without credentials configured fails with a
 * clear Cloudinary API error at call time, not a cryptic one.
 */
@Injectable()
export class CloudinaryService {
  constructor(configService: ConfigService) {
    cloudinary.config({
      cloud_name: configService.get<string>('CLOUDINARY_CLOUD_NAME'),
      api_key: configService.get<string>('CLOUDINARY_API_KEY'),
      api_secret: configService.get<string>('CLOUDINARY_API_SECRET'),
    });
  }

  uploadImage(
    file: Express.Multer.File,
    folder = 'socialhub',
  ): Promise<CloudinaryUploadResult> {
    return new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        { folder, resource_type: 'image' },
        (error, result) => {
          if (error || !result) {
            reject(error ?? new Error('Cloudinary upload returned no result.'));
            return;
          }
          resolve({ url: result.secure_url, publicId: result.public_id });
        },
      );

      streamifier.createReadStream(file.buffer).pipe(uploadStream);
    });
  }

  /**
   * Builds a delivery URL that crops/resizes an already-uploaded image to
   * exact dimensions. Used by variant generation (Milestone 4.1) to
   * produce one rendition per platform from a single master render.
   *
   * Deliberately a URL, not a re-upload: Cloudinary applies the transform
   * on first request and caches it at the CDN edge, so generating five
   * platform variants costs zero extra storage and no upload round-trips.
   * The resulting URL is publicly hosted, which is exactly what the Meta
   * Graph API requires for Instagram publishing (it cannot accept binary
   * uploads — see docs/SocialHub_Architecture_Plan.md §Platform
   * constraints).
   *
   * `crop: 'fill'` + `gravity: 'auto'` fills the target ratio exactly
   * while letting Cloudinary's content-aware gravity choose what to keep
   * — a plain scale would distort the design, and a centre crop would
   * cut the subject off whenever it isn't centred.
   */
  buildTransformedUrl(
    publicId: string,
    dimensions: { width: number; height: number },
  ): string {
    return cloudinary.url(publicId, {
      secure: true,
      transformation: [
        {
          width: dimensions.width,
          height: dimensions.height,
          crop: 'fill',
          gravity: 'auto',
        },
      ],
    });
  }
}
