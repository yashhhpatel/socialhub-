import { ServiceUnavailableException } from '@nestjs/common';
import { AIFeature } from '@prisma/client';

import { AiGatewayService } from './ai-gateway.service';

/** Minimal stand-in for the SDK's Message shape. */
function anthropicMessage(overrides: Record<string, unknown> = {}) {
  return {
    model: 'claude-opus-5',
    stop_reason: 'end_turn',
    content: [{ type: 'text', text: 'Sunday reset, minimal effort maximum vibe' }],
    usage: { input_tokens: 120, output_tokens: 18 },
    ...overrides,
  };
}

describe('AiGatewayService', () => {
  let prisma: { aIUsageLog: { create: jest.Mock } };
  let create: jest.Mock;

  const request = {
    orgId: 'org_1',
    userId: 'usr_1',
    feature: AIFeature.caption,
    systemPrompt: 'You write captions.',
    userPrompt: '<design>Text: "Hello"</design>',
  };

  /** Builds the service with the SDK client swapped for a stub. */
  function build(configured = true): AiGatewayService {
    const config = {
      get: (key: string) => (key === 'ANTHROPIC_API_KEY' && configured ? 'sk-test' : undefined),
    };
    const service = new AiGatewayService(config as never, prisma as never);
    if (configured) {
      // Replace the real SDK client — these tests must never reach the network.
      (service as unknown as { client: unknown }).client = {
        messages: { create },
      };
    }
    return service;
  }

  beforeEach(() => {
    prisma = { aIUsageLog: { create: jest.fn().mockResolvedValue({}) } };
    create = jest.fn().mockResolvedValue(anthropicMessage());
  });

  describe('configuration', () => {
    it('reports unconfigured when no API key is set', () => {
      expect(build(false).isConfigured).toBe(false);
    });

    it('refuses to generate without a key, rather than failing cryptically', async () => {
      await expect(build(false).generate(request)).rejects.toThrow(
        ServiceUnavailableException,
      );
    });
  });

  describe('generate', () => {
    it('returns the concatenated text of the response', async () => {
      const result = await build().generate(request);
      expect(result.text).toBe('Sunday reset, minimal effort maximum vibe');
    });

    it('trims whitespace the model may pad the caption with', async () => {
      create.mockResolvedValue(
        anthropicMessage({ content: [{ type: 'text', text: '\n  A caption.  \n' }] }),
      );
      expect((await build().generate(request)).text).toBe('A caption.');
    });

    it('joins multiple text blocks rather than dropping all but the first', async () => {
      create.mockResolvedValue(
        anthropicMessage({
          content: [
            { type: 'text', text: 'Part one ' },
            { type: 'text', text: 'part two' },
          ],
        }),
      );
      expect((await build().generate(request)).text).toBe('Part one part two');
    });

    it('ignores non-text blocks, which carry no caption content', async () => {
      create.mockResolvedValue(
        anthropicMessage({
          content: [
            { type: 'thinking', thinking: '' },
            { type: 'text', text: 'The caption.' },
          ],
        }),
      );
      expect((await build().generate(request)).text).toBe('The caption.');
    });

    it('sends the untrusted design content in the USER turn, never the system prompt', async () => {
      await build().generate(request);

      const args = create.mock.calls[0][0];
      expect(args.system).toBe('You write captions.');
      expect(args.system).not.toContain('<design>');
      expect(args.messages).toEqual([
        { role: 'user', content: '<design>Text: "Hello"</design>' },
      ]);
    });

    it('uses Claude Opus 5 at low effort with headroom for thinking', async () => {
      await build().generate(request);

      const args = create.mock.calls[0][0];
      expect(args.model).toBe('claude-opus-5');
      expect(args.output_config).toEqual({ effort: 'low' });
      // Thinking is on by default and shares this ceiling with the reply —
      // a tight limit truncates the caption rather than shortening it.
      expect(args.max_tokens).toBeGreaterThanOrEqual(1024);
    });
  });

  describe('failure handling', () => {
    it('does not leak the provider error message to the caller', async () => {
      create.mockRejectedValue(new Error('overloaded_error: upstream capacity'));

      await expect(build().generate(request)).rejects.toThrow(
        /temporarily unavailable/i,
      );
      await expect(build().generate(request)).rejects.not.toThrow(/overloaded_error/);
    });

    it('does NOT meter a failed call — an outage must not burn the org quota', async () => {
      create.mockRejectedValue(new Error('network down'));

      await expect(build().generate(request)).rejects.toThrow();
      expect(prisma.aIUsageLog.create).not.toHaveBeenCalled();
    });

    it('surfaces a refusal as its own message rather than an empty caption', async () => {
      create.mockResolvedValue(anthropicMessage({ stop_reason: 'refusal', content: [] }));

      await expect(build().generate(request)).rejects.toThrow(/declined/i);
      expect(prisma.aIUsageLog.create).not.toHaveBeenCalled();
    });

    it('rejects an empty response instead of returning a blank caption', async () => {
      create.mockResolvedValue(anthropicMessage({ content: [{ type: 'text', text: '   ' }] }));

      await expect(build().generate(request)).rejects.toThrow(/empty/i);
    });
  });

  describe('usage metering', () => {
    it('records the org, feature, real token counts, and serving model', async () => {
      await build().generate(request);

      expect(prisma.aIUsageLog.create).toHaveBeenCalledWith({
        data: {
          orgId: 'org_1',
          userId: 'usr_1',
          feature: AIFeature.caption,
          inputTokens: 120,
          outputTokens: 18,
          model: 'claude-opus-5',
        },
      });
    });

    it('still returns the caption when the usage write fails', async () => {
      // The user already received (and was billed for) the generation —
      // losing an accounting row beats discarding their result.
      prisma.aIUsageLog.create.mockRejectedValue(new Error('db down'));

      const result = await build().generate(request);
      expect(result.text).toBe('Sunday reset, minimal effort maximum vibe');
    });
  });
});
