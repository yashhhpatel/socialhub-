import { Injectable } from '@nestjs/common';
import { AIFeature } from '@prisma/client';

import { ContentService } from '../content/content.service';
import { AiGatewayService } from './ai-gateway.service';
import { summarizeCanvas } from './canvas-summary';
import {
  buildViralScoreUserPrompt,
  parseViralScore,
  ViralScoreResult,
  VIRAL_SCORE_SYSTEM_PROMPT,
} from './prompts/viral-score.prompt';

/**
 * Viral-score estimate for a design (Milestone 12.2). An LLM call through
 * the shared gateway (feature=viral_score), so it's usage-logged and
 * quota-metered like the other generative features.
 */
@Injectable()
export class ViralScoreService {
  constructor(
    private readonly aiGateway: AiGatewayService,
    private readonly contentService: ContentService,
  ) {}

  async scoreAsset(
    orgId: string,
    userId: string,
    assetId: string,
    caption?: string,
  ): Promise<ViralScoreResult> {
    const asset = await this.contentService.findByIdScopedWithVariants(assetId, orgId);
    const canvasSummary = summarizeCanvas(
      asset,
      'This design is empty. Add content before scoring it.',
    );

    const result = await this.aiGateway.generate({
      orgId,
      userId,
      feature: AIFeature.viral_score,
      systemPrompt: VIRAL_SCORE_SYSTEM_PROMPT,
      userPrompt: buildViralScoreUserPrompt({
        canvasSummary,
        platforms: asset.variants.map((v) => v.platform),
        caption,
      }),
    });

    return parseViralScore(result.text);
  }
}
