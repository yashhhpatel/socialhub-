import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CloudinaryService } from '../media/cloudinary.service';
import { VideoProcessingService } from '../media/video-processing.service';
import { ContentService } from './content.service';
import { ContentAssetDetailDto, ContentAssetDto } from './dto/content-asset.dto';
import { GenerateVariantsResponseDto } from './dto/content-variant.dto';
import { CreateContentAssetDto } from './dto/create-content-asset.dto';
import { GenerateVariantsDto } from './dto/generate-variants.dto';
import { ListContentAssetsDto, PaginatedDto } from './dto/list-content-assets.dto';
import { UpdateContentAssetDto } from './dto/update-content-asset.dto';
import { UploadMediaResponseDto } from './dto/upload-media-response.dto';
import { VariantGeneratorService } from './variant-generator.service';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

const ALLOWED_IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const ALLOWED_VIDEO_MIME_TYPES = ['video/mp4', 'video/quicktime', 'video/webm'];
const ALLOWED_MIME_TYPES = [...ALLOWED_IMAGE_MIME_TYPES, ...ALLOWED_VIDEO_MIME_TYPES];
// Raised from the image-only 10MB now that video (Milestone 9.2) shares
// this route — a short clip needs the headroom. The mime filter still gates
// what actually gets through.
const MAX_UPLOAD_BYTES = 100 * 1024 * 1024; // 100MB

@Controller('content/assets')
export class ContentController {
  constructor(
    private readonly contentService: ContentService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly videoProcessingService: VideoProcessingService,
    private readonly variantGenerator: VariantGeneratorService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateContentAssetDto,
  ): Promise<ContentAssetDto> {
    return this.contentService.create(req.user.orgId, req.user.userId, dto);
  }

  /**
   * Paginated content library (Milestone 3.6). Declared BEFORE the
   * `:id` route below — Nest matches in declaration order, and a bare
   * `@Get()` placed after `@Get(':id')` still works, but keeping the
   * more specific route last is the convention that avoids surprises as
   * more routes are added here.
   */
  @UseGuards(JwtAuthGuard)
  @Get()
  listAssets(
    @Req() req: AuthenticatedRequest,
    @Query() query: ListContentAssetsDto,
  ): Promise<PaginatedDto<ContentAssetDto>> {
    return this.contentService.list(req.user.orgId, query);
  }

  // Not in Milestone 3.1's literal expected output (only PATCH is named),
  // but there's no way to verify PATCH actually persisted anything
  // without a way to read it back — added for the same reason GET
  // /social-accounts was added in 2.4: making the milestone's own claim
  // independently checkable, not just asserted.
  @UseGuards(JwtAuthGuard)
  @Get(':id')
  get(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ): Promise<ContentAssetDetailDto> {
    return this.contentService.findByIdScopedWithVariants(id, req.user.orgId);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  update(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateContentAssetDto,
  ): Promise<ContentAssetDto> {
    return this.contentService.update(id, req.user.orgId, dto);
  }

  /**
   * Uploads a single media file for use on the canvas. Images go through
   * CloudinaryService; videos (Milestone 9.2) go through
   * VideoProcessingService, which also yields a poster still the canvas
   * video layer displays. Returns a bare hosted URL (+ publicId, + poster
   * for video), deliberately not tied to any specific ContentAsset — the
   * editor embeds the returned url inside a layer's own canvasJson via the
   * existing PATCH endpoint.
   */
  @UseGuards(JwtAuthGuard)
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
  async uploadMedia(
    @UploadedFile() file: Express.Multer.File,
  ): Promise<UploadMediaResponseDto> {
    if (!file) {
      throw new BadRequestException('No file provided under the "file" field.');
    }

    if (ALLOWED_VIDEO_MIME_TYPES.includes(file.mimetype)) {
      const result = await this.videoProcessingService.uploadVideo(file);
      return {
        url: result.url,
        publicId: result.publicId,
        // The frame at 0s, so the editor has a poster to show immediately.
        posterUrl: this.videoProcessingService.buildPosterUrl(result.publicId),
      };
    }

    const result = await this.cloudinaryService.uploadImage(file);
    return { url: result.url, publicId: result.publicId };
  }

  /**
   * Fans one asset out into per-platform renditions (Milestone 4.1).
   *
   * 202, not 201, per docs/SocialHub_REST_API_Design.md. Generation is
   * synchronous today — Cloudinary applies the transform lazily on first
   * delivery, so there's nothing to wait for — but Phase 7 moves this
   * onto a queue. Publishing the async-shaped contract now means the
   * frontend written against it needs no change then, and 202 does not
   * promise the work is incomplete, only that it was accepted.
   */
  @UseGuards(JwtAuthGuard)
  @Post(':id/variants')
  @HttpCode(HttpStatus.ACCEPTED)
  async generateVariants(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: GenerateVariantsDto,
  ): Promise<GenerateVariantsResponseDto> {
    // Scoped lookup first, so an asset belonging to another org 404s
    // before any generation work is attempted.
    const asset = await this.contentService.findByIdScoped(id, req.user.orgId);
    const variants = await this.variantGenerator.generate(asset, dto.platforms);
    return { variants };
  }
}
