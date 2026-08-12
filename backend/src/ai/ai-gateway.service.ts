import Anthropic from '@anthropic-ai/sdk';
import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AIFeature } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

/** What every AI feature hands the gateway. */
export interface AiGenerationRequest {
  orgId: string;
  userId?: string;
  feature: AIFeature;
  systemPrompt: string;
  userPrompt: string;
  /** Ceiling on the whole response — see the note on thinking below. */
  maxTokens?: number;
}

export interface AiGenerationResult {
  text: string;
  inputTokens: number;
  outputTokens: number;
  model: string;
}

/**
 * The single place this application talks to an LLM (Milestone 5.1).
 *
 * Provider-agnostic by intent, per the blueprint: every AI feature depends
 * on this service's interface, not on the Anthropic SDK. That is what keeps
 * a provider swap to one file rather than five feature modules, and it is
 * why the request/result types above are plain shapes rather than SDK types
 * re-exported.
 *
 * Usage is logged HERE rather than in each feature, so a new AI endpoint
 * (Phase 12 adds four) cannot accidentally ship without metering — the
 * quota guard in Milestone 5.2 reads exactly what this writes.
 */
@Injectable()
export class AiGatewayService {
  private readonly logger = new Logger(AiGatewayService.name);
  private readonly client: Anthropic | null;

  /**
   * Claude Opus 5. Deliberately a constant rather than an env var: the
   * prompts in prompts/ are tuned against this model's behaviour, and a
   * silent per-environment model swap would change output quality with
   * nothing in the diff to explain it. Changing models should be a code
   * change that goes through review.
   */
  private static readonly MODEL = 'claude-opus-5';

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const apiKey = this.configService.get<string>('ANTHROPIC_API_KEY');

    // Optional at boot, same reasoning as Cloudinary and the OAuth
    // credentials (Milestones 2.2/3.2): a developer without an Anthropic
    // key should still be able to run the rest of the app. A call without
    // one fails with a clear message at request time, not a cryptic crash
    // at startup.
    this.client = apiKey ? new Anthropic({ apiKey }) : null;
  }

  get isConfigured(): boolean {
    return this.client !== null;
  }

  async generate(request: AiGenerationRequest): Promise<AiGenerationResult> {
    if (!this.client) {
      throw new ServiceUnavailableException(
        'AI features are not configured on this server (ANTHROPIC_API_KEY is missing).',
      );
    }

    let response: Anthropic.Message;
    try {
      response = await this.client.messages.create({
        model: AiGatewayService.MODEL,
        // Generous relative to a caption's length because this ceiling
        // covers thinking AND the reply — thinking is on by default on
        // Opus 5, so a tight limit truncates the answer mid-sentence
        // rather than merely shortening it.
        max_tokens: request.maxTokens ?? 4096,
        // Short, scoped generation: low effort keeps latency and cost down
        // without disabling thinking, which is the documented failure-prone
        // path (tool calls leaking into text, internal tags in output).
        output_config: { effort: 'low' },
        system: request.systemPrompt,
        messages: [{ role: 'user', content: request.userPrompt }],
      });
    } catch (error) {
      // The provider's own message is logged but NOT returned to the
      // client: it can echo prompt content, and the caller can't act on
      // "overloaded_error" anyway.
      this.logger.error(
        `AI generation failed for ${request.feature}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      throw new ServiceUnavailableException(
        'The AI service is temporarily unavailable. Please try again.',
      );
    }

    if (response.stop_reason === 'refusal') {
      throw new ServiceUnavailableException(
        'The AI declined to generate content for this design. Try adjusting the design or tone.',
      );
    }

    const text = response.content
      .filter((block): block is Anthropic.TextBlock => block.type === 'text')
      .map((block) => block.text)
      .join('')
      .trim();

    if (!text) {
      throw new ServiceUnavailableException(
        'The AI returned an empty response. Please try again.',
      );
    }

    // Logged only after a successful generation. A provider outage costs
    // the org nothing, so metering a failed call would let downtime burn a
    // customer's monthly allowance.
    await this.recordUsage(request, response);

    return {
      text,
      inputTokens: response.usage.input_tokens,
      outputTokens: response.usage.output_tokens,
      model: response.model,
    };
  }

  /**
   * Never throws. A failed usage write must not fail a generation the user
   * already paid for and received — the row is for quota accounting, and
   * losing one is strictly better than discarding a successful result.
   */
  private async recordUsage(
    request: AiGenerationRequest,
    response: Anthropic.Message,
  ): Promise<void> {
    try {
      await this.prisma.aIUsageLog.create({
        data: {
          orgId: request.orgId,
          userId: request.userId,
          feature: request.feature,
          inputTokens: response.usage.input_tokens,
          outputTokens: response.usage.output_tokens,
          model: response.model,
        },
      });
    } catch (error) {
      this.logger.error(
        `Failed to record AI usage for org ${request.orgId}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }
}
