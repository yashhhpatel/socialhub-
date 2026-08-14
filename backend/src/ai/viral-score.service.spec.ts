import { UnprocessableEntityException } from '@nestjs/common';
import { AIFeature } from '@prisma/client';

import { parseViralScore } from './prompts/viral-score.prompt';
import { ViralScoreService } from './viral-score.service';

describe('ViralScoreService', () => {
  let service: ViralScoreService;
  let aiGateway: { generate: jest.Mock };
  let contentService: { findByIdScopedWithVariants: jest.Mock };

  const asset = {
    id: 'asset_1',
    canvasJson: { layers: [{ type: 'text', text: 'Big launch' }] },
    variants: [{ platform: 'instagram' }],
  };

  beforeEach(() => {
    aiGateway = { generate: jest.fn().mockResolvedValue({ text: 'SCORE: 82\nREASON: Strong hook.' }) };
    contentService = { findByIdScopedWithVariants: jest.fn().mockResolvedValue(asset) };
    service = new ViralScoreService(aiGateway as never, contentService as never);
  });

  it('scores via the gateway (feature=viral_score), factoring in the caption', async () => {
    const result = await service.scoreAsset('org_1', 'u_1', 'asset_1', 'Launch day is here');

    const req = aiGateway.generate.mock.calls[0][0];
    expect(req.feature).toBe(AIFeature.viral_score);
    expect(req.userPrompt).toContain('<caption>');
    expect(req.userPrompt).toContain('Launch day is here');
    expect(result).toEqual({ score: 82, rationale: 'Strong hook.' });
  });

  it('422s an empty design before calling the model', async () => {
    contentService.findByIdScopedWithVariants.mockResolvedValue({
      ...asset,
      canvasJson: { layers: [] },
    });
    await expect(service.scoreAsset('org_1', 'u_1', 'asset_1')).rejects.toBeInstanceOf(
      UnprocessableEntityException,
    );
    expect(aiGateway.generate).not.toHaveBeenCalled();
  });
});

describe('parseViralScore', () => {
  it('extracts the score and reason from the fixed format', () => {
    expect(parseViralScore('SCORE: 73\nREASON: Clear value prop.')).toEqual({
      score: 73,
      rationale: 'Clear value prop.',
    });
  });

  it('clamps out-of-range scores to 0–100', () => {
    expect(parseViralScore('SCORE: 140\nREASON: x').score).toBe(100);
    expect(parseViralScore('SCORE: -5\nREASON: x').score).toBe(0);
  });

  it('tolerates surrounding chatter and case', () => {
    expect(parseViralScore('Here is my rating. score = 61. reason = decent.').score).toBe(61);
  });

  it('falls back to a neutral 50 when no number is present', () => {
    expect(parseViralScore('I cannot rate this.')).toEqual({ score: 50, rationale: '' });
  });
});
