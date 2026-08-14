import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AiSuiteService } from './ai-suite.service';
import { CaptionService } from './caption.service';
import {
  ConvertToneDto,
  ConvertToneResponseDto,
} from './dto/convert-tone.dto';
import {
  GenerateCaptionDto,
  GenerateCaptionResponseDto,
} from './dto/generate-caption.dto';
import {
  GenerateHashtagsDto,
  GenerateHashtagsResponseDto,
} from './dto/generate-hashtags.dto';
import { QuotaGuard } from './quota.guard';

interface AuthenticatedRequest extends Request {
  user: { userId: string; email: string; role: string; orgId: string };
}

@Controller('ai')
export class AiController {
  constructor(
    private readonly captionService: CaptionService,
    private readonly aiSuiteService: AiSuiteService,
  ) {}

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
  @UseGuards(JwtAuthGuard, RolesGuard, QuotaGuard)
  @Roles(UserRole.editor)
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

  /**
   * Hashtag suggestions for a saved design (Milestone 12.1). Same guard
   * stack as captions — editor+, and metered by QuotaGuard against the
   * shared AI allowance.
   */
  @UseGuards(JwtAuthGuard, RolesGuard, QuotaGuard)
  @Roles(UserRole.editor)
  @Post('hashtags')
  async generateHashtags(
    @Req() req: AuthenticatedRequest,
    @Body() dto: GenerateHashtagsDto,
  ): Promise<GenerateHashtagsResponseDto> {
    const hashtags = await this.aiSuiteService.generateHashtags(
      req.user.orgId,
      req.user.userId,
      dto.assetId,
      dto.count ?? 10,
    );
    return { hashtags };
  }

  /** Rewrites supplied copy in a target tone (Milestone 12.1). */
  @UseGuards(JwtAuthGuard, RolesGuard, QuotaGuard)
  @Roles(UserRole.editor)
  @Post('tone')
  async convertTone(
    @Req() req: AuthenticatedRequest,
    @Body() dto: ConvertToneDto,
  ): Promise<ConvertToneResponseDto> {
    const text = await this.aiSuiteService.convertTone(
      req.user.orgId,
      req.user.userId,
      dto.text,
      dto.tone,
    );
    return { text };
  }
}
