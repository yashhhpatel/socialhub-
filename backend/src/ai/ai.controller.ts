import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CaptionService } from './caption.service';
import {
  GenerateCaptionDto,
  GenerateCaptionResponseDto,
} from './dto/generate-caption.dto';
import { QuotaGuard } from './quota.guard';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@Controller('ai')
export class AiController {
  constructor(private readonly captionService: CaptionService) {}

  /**
   * Generates a caption for a saved design (Milestone 5.1).
   *
   * 200, not 202: unlike variant generation and publishing, this returns
   * the actual result the caller asked for and there is no job to poll.
   *
   * QuotaGuard runs after JwtAuthGuard (which populates the `orgId` it
   * meters on) and before the handler, so an org over its allowance is
   * turned away with a 429 and a resetAt before any tokens are spent.
   */
  @UseGuards(JwtAuthGuard, QuotaGuard)
  @Post('caption')
  async generateCaption(
    @Req() req: AuthenticatedRequest,
    @Body() dto: GenerateCaptionDto,
  ): Promise<GenerateCaptionResponseDto> {
    const caption = await this.captionService.generateForAsset(
      req.user.orgId,
      req.user.userId,
      dto.assetId,
      dto.tone,
    );
    return { caption };
  }
}
