import { Injectable } from '@nestjs/common';
import { AIFeature, Platform } from '@prisma/client';

import { ContentService } from '../content/content.service';
import { FacebookAdapter } from '../social-accounts/adapters/facebook.adapter';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { LinkedInAdapter } from '../social-accounts/adapters/linkedin.adapter';
import { ThreadsAdapter } from '../social-accounts/adapters/threads.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import { AiGatewayService } from './ai-gateway.service';
import { summarizeCanvas } from './canvas-summary';
import {
  buildCaptionUserPrompt,
  CaptionTone,
  CAPTION_SYSTEM_PROMPT,
} from './prompts/caption.prompt';

/**
 * Turns a saved design into a caption (Milestone 5.1).
 *
 * The interesting part is deriving prompt context from canvasJson: the model
 * cannot see the artboard, so the only thing it has to work from is what
 * this function extracts. Text layers carry nearly all the meaning; shapes
 * and images contribute composition, not subject matter.
 */
@Injectable()
export class CaptionService {
  constructor(
    private readonly aiGateway: AiGatewayService,
    private readonly contentService: ContentService,
    private readonly instagramAdapter: InstagramAdapter,
    private readonly xAdapter: XAdapter,
    private readonly facebookAdapter: FacebookAdapter,
    private readonly threadsAdapter: ThreadsAdapter,
    private readonly linkedinAdapter: LinkedInAdapter,
  ) {}

  async generateForAsset(
    orgId: string,
    userId: string,
    assetId: string,
    tone?: CaptionTone,
  ): Promise<string> {
    const asset = await this.contentService.findByIdScopedWithVariants(assetId, orgId);

    const canvasSummary = summarizeCanvas(
      asset,
      'This design is empty. Add text or images before generating a caption.',
    );
    const platforms = asset.variants.map((v) => v.platform);

    const result = await this.aiGateway.generate({
      orgId,
      userId,
      feature: AIFeature.caption,
      systemPrompt: CAPTION_SYSTEM_PROMPT,
      userPrompt: buildCaptionUserPrompt({
        canvasSummary,
        tone,
        platforms,
        maxCaptionLength: this.tightestCaptionLimit(platforms),
      }),
    });

    return result.text;
  }

  /**
   * The SHORTEST limit across the asset's target platforms, not the most
   * generous — one caption is written for all of them, so a 2200-character
   * Instagram caption that can't be posted to X is useless. Falls back to
   * X's 280 when no variants exist yet, which is the safe direction to be
   * wrong in.
   */
  private tightestCaptionLimit(platforms: Platform[]): number {
    const limits = platforms
      .map((platform) => {
        switch (platform) {
          case Platform.instagram:
            return this.instagramAdapter.capabilities().maxCaptionLength;
          case Platform.x:
            return this.xAdapter.capabilities().maxCaptionLength;
          case Platform.facebook:
            return this.facebookAdapter.capabilities().maxCaptionLength;
          case Platform.threads:
            return this.threadsAdapter.capabilities().maxCaptionLength;
          case Platform.linkedin:
            return this.linkedinAdapter.capabilities().maxCaptionLength;
          default:
            return null;
        }
      })
      .filter((limit): limit is number => limit !== null);

    return limits.length > 0
      ? Math.min(...limits)
      : this.xAdapter.capabilities().maxCaptionLength;
  }

}
