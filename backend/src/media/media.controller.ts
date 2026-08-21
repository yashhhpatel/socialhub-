import {
  BadRequestException,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { MediaAsset, UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { CloudinaryService } from './cloudinary.service';
import { MediaAssetDto } from './dto/media-asset.dto';
import { MediaService } from './media.service';
import { VideoProcessingService } from './video-processing.service';

interface AuthedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

const ALLOWED_IMAGE_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];
const ALLOWED_VIDEO_MIME_TYPES = ['video/mp4', 'video/quicktime', 'video/webm'];
const ALLOWED_MIME_TYPES = [...ALLOWED_IMAGE_MIME_TYPES, ...ALLOWED_VIDEO_MIME_TYPES];
const MAX_UPLOAD_BYTES = 100 * 1024 * 1024; // 100MB

/// Persistent media library (Phase 19): upload → Cloudinary (image) or the
/// video pipeline, then a durable MediaAsset row so the org's uploads survive
/// across sessions. Uploads are editor+ (like content uploads); reads are any
/// signed-in member.
@Controller('media')
export class MediaController {
  constructor(
    private readonly media: MediaService,
    private readonly cloudinary: CloudinaryService,
    private readonly videoProcessing: VideoProcessingService,
  ) {}

  /// The org's media library, newest first.
  @UseGuards(JwtAuthGuard)
  @Get()
  async list(@Req() req: AuthedRequest): Promise<MediaAssetDto[]> {
    const assets = await this.media.listForOrg(req.user.orgId);
    return assets.map(toDto);
  }

  /// Upload a file and persist it to the library.
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_UPLOAD_BYTES },
      fileFilter: (req, file, callback) => {
        if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
          callback(
            new BadRequestException(
              `Unsupported file type. Allowed: ${ALLOWED_MIME_TYPES.join(', ')}.`,
            ),
            false,
          );
          return;
        }
        callback(null, true);
      },
    }),
  )
  async upload(
    @Req() req: AuthedRequest,
    @UploadedFile() file: Express.Multer.File,
  ): Promise<MediaAssetDto> {
    if (!file) {
      throw new BadRequestException('No file provided under the "file" field.');
    }

    if (ALLOWED_VIDEO_MIME_TYPES.includes(file.mimetype)) {
      const result = await this.videoProcessing.uploadVideo(file);
      const asset = await this.media.record({
        orgId: req.user.orgId,
        createdById: req.user.userId,
        url: result.url,
        publicId: result.publicId,
        type: 'video',
        name: file.originalname,
        posterUrl: this.videoProcessing.buildPosterUrl(result.publicId),
      });
      return toDto(asset);
    }

    const result = await this.cloudinary.uploadImage(file);
    const asset = await this.media.record({
      orgId: req.user.orgId,
      createdById: req.user.userId,
      url: result.url,
      publicId: result.publicId,
      type: 'image',
      name: file.originalname,
    });
    return toDto(asset);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.editor)
  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id')
  async remove(
    @Req() req: AuthedRequest,
    @Param('id') id: string,
  ): Promise<void> {
    await this.media.remove(id, req.user.orgId);
  }
}

function toDto(a: MediaAsset): MediaAssetDto {
  return {
    id: a.id,
    url: a.url,
    publicId: a.publicId,
    type: a.type,
    name: a.name,
    posterUrl: a.posterUrl,
    createdAt: a.createdAt,
  };
}
