import { ServiceUnavailableException } from '@nestjs/common';
import { AIFeature } from '@prisma/client';

import { AiGatewayService } from './ai-gateway.service';

/** Minimal stand-in for the OpenAI ChatCompletion shape. */
function openAiCompletion(overrides: Record<string, unknown> = {}) {
  const {
    content = 'Sunday reset, minimal effort maximum vibe',
    refusal = null,
    finish_reason = 'stop',
    ...rest
  } = overrides as {
    content?: string | null;
    refusal?: string | null;
    finish_reason?: string;
  };
  return {
    model: 'gpt-4o-mini-2024-07-18',
    choices: [
      {
        finish_reason,
        message: { role: 'assistant', content, refusal },
      },
    ],
    usage: { prompt_tokens: 120, completion_tokens: 18, total_tokens: 138 },
    ...rest,
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
      get: (key: string) =>
        key === 'OPENAI_API_KEY' && configured ? 'sk-test' : undefined,
    };
    const service = new AiGatewayService(config as never, prisma as never);
    if (configured) {
      // Replace the real SDK client — these tests must never reach the network.
      (service as unknown as { client: unknown }).client = {
        chat: { completions: { create } },
      };
    }
    return service;
  }

  beforeEach(() => {
    prisma = { aIUsageLog: { create: jest.fn().mockResolvedValue({}) } };
    create = jest.fn().mockResolvedValue(openAiCompletion());
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
    it('returns the text of the response', async () => {
      const result = await build().generate(request);
      expect(result.text).toBe('Sunday reset, minimal effort maximum vibe');
    });

    it('trims whitespace the model may pad the caption with', async () => {
      create.mockResolvedValue(openAiCompletion({ content: '\n  A caption.  \n' }));
      expect((await build().generate(request)).text).toBe('A caption.');
    });

    it('sends the untrusted design content in the USER turn, never the system prompt', async () => {
      await build().generate(request);

      const args = create.mock.calls[0][0];
      expect(args.messages).toEqual([
        { role: 'system', content: 'You write captions.' },
        { role: 'user', content: '<design>Text: "Hello"</design>' },
      ]);
      // The design must not have leaked into the system instructions.
      expect(args.messages[0].content).not.toContain('<design>');
    });

    it('uses gpt-4o-mini with room for the reply', async () => {
      await build().generate(request);

      const args = create.mock.calls[0][0];
      expect(args.model).toBe('gpt-4o-mini');
      expect(args.max_tokens).toBeGreaterThanOrEqual(1024);
    });
  });

  describe('failure handling', () => {
    it('does not leak the provider error message to the caller', async () => {
      create.mockRejectedValue(new Error('rate_limit_exceeded: upstream capacity'));

      await expect(build().generate(request)).rejects.toThrow(
        /temporarily unavailable/i,
      );
      await expect(build().generate(request)).rejects.not.toThrow(/rate_limit/);
    });

    it('does NOT meter a failed call — an outage must not burn the org quota', async () => {
      create.mockRejectedValue(new Error('network down'));

      await expect(build().generate(request)).rejects.toThrow();
      expect(prisma.aIUsageLog.create).not.toHaveBeenCalled();
    });

    it('surfaces a refusal as its own message rather than an empty caption', async () => {
      create.mockResolvedValue(
        openAiCompletion({ content: null, refusal: 'I cannot help with that.' }),
      );

      await expect(build().generate(request)).rejects.toThrow(/declined/i);
      expect(prisma.aIUsageLog.create).not.toHaveBeenCalled();
    });

    it('rejects an empty response instead of returning a blank caption', async () => {
      create.mockResolvedValue(openAiCompletion({ content: '   ' }));

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
          model: 'gpt-4o-mini-2024-07-18',
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
