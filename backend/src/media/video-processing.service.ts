import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary } from 'cloudinary';
import * as streamifier from 'streamifier';

import { CloudinaryUploadResult } from './cloudinary.service';

/** Per-platform target for a transcoded/trimmed video rendition. */
export interface VideoTransformSpec {
  width: number;
  height: number;
  /**
   * Hard cap on the output length, in seconds — the platform's own video
   * ceiling. Cloudinary trims to this automatically ("transcoded/trimmed
   * per platform spec"), so a clip longer than a platform allows is cut to
   * fit rather than rejected at publish time. Omit for no cap.
   */
  maxDurationSeconds?: number;
}

/**
 * Video half of the media pipeline (Milestone 9.2) — the counterpart to
 * CloudinaryService's image handling, kept separate because video upload
 * and transformation are their own concern (transcode, trim, poster) and
 * this is exactly the file the blueprint carves out for it.
 *
 * Like CloudinaryService, config is read with `get()` (not `getOrThrow()`)
 * and CLOUDINARY_* stays out of the boot schema: video is an optional
 * feature, and an upload without credentials should fail at call time with
 * a clear Cloudinary error, not stop the app from booting.
 *
 * Transformations are delivered as URLs, not re-encoded on our servers:
 * Cloudinary transcodes on first request and caches at the edge, so five
 * platform renditions cost no extra storage and no local ffmpeg.
 */
@Injectable()
export class VideoProcessingService {
  constructor(configService: ConfigService) {
    cloudinary.config({
      cloud_name: configService.get<string>('CLOUDINARY_CLOUD_NAME'),
      api_key: configService.get<string>('CLOUDINARY_API_KEY'),
      api_secret: configService.get<string>('CLOUDINARY_API_SECRET'),
    });
  }

  /** Uploads a source video, returning its hosted URL + public id. */
  uploadVideo(
    file: Express.Multer.File,
    folder = 'socialhub',
  ): Promise<CloudinaryUploadResult> {
    return new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        { folder, resource_type: 'video' },
        (error, result) => {
          if (error || !result) {
            reject(error ?? new Error('Cloudinary video upload returned no result.'));
            return;
          }
          resolve({ url: result.secure_url, publicId: result.public_id });
        },
      );

      streamifier.createReadStream(file.buffer).pipe(uploadStream);
    });
  }

  /**
   * Builds a delivery URL that transcodes an uploaded video to MP4, crops
   * it to the platform's exact frame size, and trims it to the platform's
   * duration ceiling — the video analogue of
   * CloudinaryService.buildTransformedUrl.
   *
   * `crop: 'fill'` + `gravity: 'auto'` matches the image path: fill the
   * target ratio exactly, letting Cloudinary keep the salient region rather
   * than distorting or blindly centre-cropping. `duration` trims from the
   * start; a fuller start/end trim window is a later refinement.
   */
  buildTransformedVideoUrl(publicId: string, spec: VideoTransformSpec): string {
    return cloudinary.url(publicId, {
      resource_type: 'video',
      secure: true,
      format: 'mp4',
      transformation: [
        {
          width: spec.width,
          height: spec.height,
          crop: 'fill',
          gravity: 'auto',
        },
        if_trim(spec.maxDurationSeconds),
      ].filter((t): t is Record<string, unknown> => t !== null),
    });
  }

  /**
   * Builds a poster (still frame) URL for a video — a single JPG frame,
   * used as the canvas poster and the master-render stand-in for a video
   * layer (the frontend can't rasterize live video). Defaults to the frame
   * at 0s.
   */
  buildPosterUrl(publicId: string, atSeconds = 0): string {
    return cloudinary.url(publicId, {
      resource_type: 'video',
      secure: true,
      format: 'jpg',
      transformation: [{ start_offset: atSeconds }],
    });
  }
}

/** The duration-cap transformation segment, or null when uncapped. */
function if_trim(maxDurationSeconds?: number): Record<string, unknown> | null {
  if (maxDurationSeconds === undefined) return null;
  return { duration: maxDurationSeconds };
}
