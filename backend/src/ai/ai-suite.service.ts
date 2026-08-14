import { Injectable } from '@nestjs/common';
import { AIFeature } from '@prisma/client';

import { ContentService } from '../content/content.service';
import { AiGatewayService } from './ai-gateway.service';
import { summarizeCanvas } from './canvas-summary';
import {
  buildHashtagsUserPrompt,
  HASHTAGS_SYSTEM_PROMPT,
  parseHashtags,
} from './prompts/hashtags.prompt';
import { CaptionTone } from './prompts/caption.prompt';
import { buildToneUserPrompt, TONE_SYSTEM_PROMPT } from './prompts/tone.prompt';

/**
 * Hashtag suggestions and tone conversion (Milestone 12.1) — the first two
 * of Phase 12's AI features. Both go through the same AiGatewayService as
 * captions, so usage logging and (via QuotaGuard) the shared allowance apply
 * to them exactly as to captions; only the prompt differs per feature.
 */
@Injectable()
export class AiSuiteService {
  constructor(
    private readonly aiGateway: AiGatewayService,
    private readonly contentService: ContentService,
  ) {}

  async generateHashtags(
    orgId: string,
    userId: string,
    assetId: string,
    count: number,
  ): Promise<string[]> {
    const asset = await this.contentService.findByIdScopedWithVariants(assetId, orgId);
    const canvasSummary = summarizeCanvas(
      asset,
      'This design is empty. Add text or images before generating hashtags.',
    );

    const result = await this.aiGateway.generate({
      orgId,
      userId,
      feature: AIFeature.hashtags,
      systemPrompt: HASHTAGS_SYSTEM_PROMPT,
      userPrompt: buildHashtagsUserPrompt({
        canvasSummary,
        platforms: asset.variants.map((v) => v.platform),
        count,
      }),
    });

    // Cap client-side too: the model doesn't always honour the exact count.
    return parseHashtags(result.text, count);
  }

  async convertTone(
    orgId: string,
    userId: string,
    text: string,
    tone: CaptionTone,
  ): Promise<string> {
    const result = await this.aiGateway.generate({
      orgId,
      userId,
      feature: AIFeature.tone,
      systemPrompt: TONE_SYSTEM_PROMPT,
      userPrompt: buildToneUserPrompt({ text, tone }),
    });
    return result.text.trim();
  }
}
