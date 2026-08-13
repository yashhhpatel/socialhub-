import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import { AIFeature, ContentAsset, Platform } from '@prisma/client';

import { ContentService } from '../content/content.service';
import { FacebookAdapter } from '../social-accounts/adapters/facebook.adapter';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import { AiGatewayService } from './ai-gateway.service';
import {
  buildCaptionUserPrompt,
  CaptionTone,
  CAPTION_SYSTEM_PROMPT,
} from './prompts/caption.prompt';

interface CanvasLayer {
  type?: string;
  text?: string;
  shapeKind?: string;
}

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
  ) {}

  async generateForAsset(
    orgId: string,
    userId: string,
    assetId: string,
    tone?: CaptionTone,
  ): Promise<string> {
    const asset = await this.contentService.findByIdScopedWithVariants(assetId, orgId);

    const canvasSummary = this.summarizeCanvas(asset);
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
          default:
            return null;
        }
      })
      .filter((limit): limit is number => limit !== null);

    return limits.length > 0
      ? Math.min(...limits)
      : this.xAdapter.capabilities().maxCaptionLength;
  }

  /**
   * Describes the design in words. 422s on an empty canvas rather than
   * asking the model to caption nothing — per the REST design doc, "422 if
   * asset has no visual content yet to caption".
   */
  private summarizeCanvas(asset: ContentAsset): string {
    const canvas = asset.canvasJson as { layers?: CanvasLayer[] } | null;
    const layers = Array.isArray(canvas?.layers) ? canvas.layers : [];

    if (layers.length === 0) {
      throw new UnprocessableEntityException(
        'This design is empty. Add text or images before generating a caption.',
      );
    }

    const texts = layers
      .filter((l) => l.type === 'text' && typeof l.text === 'string' && l.text.trim())
      .map((l) => (l.text as string).trim());

    const imageCount = layers.filter((l) => l.type === 'image').length;
    const shapeCount = layers.filter((l) => l.type === 'shape').length;

    const parts: string[] = [];

    if (texts.length > 0) {
      parts.push(`Text on the design:\n${texts.map((t) => `- "${t}"`).join('\n')}`);
    }
    if (imageCount > 0) {
      parts.push(`${imageCount} image${imageCount === 1 ? '' : ''} placed on the design.`);
    }
    if (shapeCount > 0) {
      parts.push(`${shapeCount} decorative shape${shapeCount === 1 ? '' : 's'}.`);
    }

    // Text-free designs are captionable but much weaker — say so plainly
    // rather than letting the model invent a subject it cannot see.
    if (texts.length === 0) {
      parts.push(
        'The design contains no text, so its subject matter is not described here. Keep the caption general rather than guessing at specifics.',
      );
    }

    return parts.join('\n\n');
  }
}
