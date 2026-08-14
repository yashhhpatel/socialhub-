import { UnprocessableEntityException } from '@nestjs/common';
import { AIFeature } from '@prisma/client';

import { AiSuiteService } from './ai-suite.service';
import { parseHashtags } from './prompts/hashtags.prompt';

describe('AiSuiteService', () => {
  let service: AiSuiteService;
  let aiGateway: { generate: jest.Mock };
  let contentService: { findByIdScopedWithVariants: jest.Mock };

  const asset = {
    id: 'asset_1',
    orgId: 'org_1',
    canvasJson: { width: 1080, height: 1080, layers: [{ type: 'text', text: 'Cold brew season' }] },
    variants: [{ platform: 'instagram' }],
  };

  beforeEach(() => {
    aiGateway = { generate: jest.fn() };
    contentService = { findByIdScopedWithVariants: jest.fn().mockResolvedValue(asset) };
    service = new AiSuiteService(aiGateway as never, contentService as never);
  });

  describe('generateHashtags', () => {
    it('summarizes the design, calls the gateway with the hashtags feature, and parses the output', async () => {
      aiGateway.generate.mockResolvedValue({ text: '#coldbrew #coffee #summer #cafe' });

      const tags = await service.generateHashtags('org_1', 'u_1', 'asset_1', 3);

      const req = aiGateway.generate.mock.calls[0][0];
      expect(req.feature).toBe(AIFeature.hashtags);
      expect(req.orgId).toBe('org_1');
      // The design's text is wrapped as untrusted material, not spliced into
      // the system prompt.
      expect(req.userPrompt).toContain('<design>');
      expect(req.userPrompt).toContain('Cold brew season');
      // Capped to the requested count even though the model returned 4.
      expect(tags).toEqual(['#coldbrew', '#coffee', '#summer']);
    });

    it('422s an empty design before spending any quota', async () => {
      contentService.findByIdScopedWithVariants.mockResolvedValue({
        ...asset,
        canvasJson: { width: 1, height: 1, layers: [] },
      });

      await expect(
        service.generateHashtags('org_1', 'u_1', 'asset_1', 5),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);
      expect(aiGateway.generate).not.toHaveBeenCalled();
    });
  });

  describe('convertTone', () => {
    it('sends the text as untrusted material and returns the rewrite trimmed', async () => {
      aiGateway.generate.mockResolvedValue({ text: '  Big news, friends! ☕  ' });

      const out = await service.convertTone('org_1', 'u_1', 'We have coffee.', 'playful');

      const req = aiGateway.generate.mock.calls[0][0];
      expect(req.feature).toBe(AIFeature.tone);
      expect(req.userPrompt).toContain('<text>');
      expect(req.userPrompt).toContain('We have coffee.');
      expect(req.userPrompt).toContain('playful');
      expect(out).toBe('Big news, friends! ☕');
    });
  });
});

describe('parseHashtags', () => {
  it('keeps only #-prefixed tokens, de-dupes case-insensitively, and caps to the limit', () => {
    const raw = 'Here: #Coffee #coffee #ColdBrew plain, #Cafe! #Summer #Fall';
    expect(parseHashtags(raw, 3)).toEqual(['#Coffee', '#ColdBrew', '#Cafe']);
  });

  it('returns an empty list when the model emitted no usable tags', () => {
    expect(parseHashtags('sorry, I cannot do that', 5)).toEqual([]);
  });
});
