import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CloudinaryService } from '../media/cloudinary.service';
import { ContentService } from './content.service';
import { ContentAssetDto } from './dto/content-asset.dto';
import { CreateContentAssetDto } from './dto/create-content-asset.dto';
import { UpdateContentAssetDto } from './dto/update-content-asset.dto';
import { UploadMediaResponseDto } from './dto/upload-media-response.dto';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

const ALLOWED_IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_UPLOAD_BYTES = 10 * 1024 * 1024; // 10MB

@Controller('content/assets')
export class ContentController {
  constructor(
    private readonly contentService: ContentService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateContentAssetDto,
  ): Promise<ContentAssetDto> {
    return this.contentService.create(req.user.orgId, req.user.userId, dto);
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
  ): Promise<ContentAssetDto> {
    return this.contentService.findByIdScoped(id, req.user.orgId);
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
   * Image-only for this milestone — video upload/processing is Phase 9's
   * job (a real transcoding pipeline, not a plain Cloudinary passthrough).
   * Returns a bare hosted URL, deliberately not tied to any specific
   * ContentAsset — the editor calls this per-image as the user adds one
   * to the canvas, then embeds the returned url inside a layer's own
   * canvasJson via the existing PATCH endpoint, which already accepts
   * arbitrary layer content (see dto/canvas-json.dto.ts).
   */
  @UseGuards(JwtAuthGuard)
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_UPLOAD_BYTES },
      fileFilter: (req, file, callback) => {
        if (!ALLOWED_IMAGE_MIME_TYPES.includes(file.mimetype)) {
          callback(
            new BadRequestException(
              `Unsupported file type. Allowed: ${ALLOWED_IMAGE_MIME_TYPES.join(', ')}.`,
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

    const result = await this.cloudinaryService.uploadImage(file);
    return { url: result.url };
  }
}
