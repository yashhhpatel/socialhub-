import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AIFeature } from '@prisma/client';
import OpenAI from 'openai';

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
 * Placeholder outputs used ONLY as a development fallback (see
 * AiGatewayService.handleUnavailable). Each is shaped so the feature's own
 * parser accepts it — hashtags need `#` tokens, viral score needs a
 * `score:`/`reason:` pair — so the whole AI flow works end to end locally
 * without a billed key. Never returned in production.
 */
const DEV_STUB_TEXT: Partial<Record<AIFeature, string>> = {
  [AIFeature.caption]:
    '✨ Sample caption from development mode — configure an AI provider ' +
    '(OPENAI_API_KEY + billing) to generate real captions.',
  [AIFeature.hashtags]:
    '#socialhub #sample #devmode #placeholder #contentmarketing ' +
    '#socialmedia #demo #configureai #stub #comingsoon #marketing #brand',
  [AIFeature.tone]:
    'Development-mode rewrite: configure an AI provider to get a real ' +
    'tone conversion here.',
  [AIFeature.viral_score]:
    'score: 72\nreason: Development placeholder — configure an AI provider ' +
    'for a real estimate.',
};

const DEV_STUB_DEFAULT =
  'Development placeholder — configure an AI provider to enable this feature.';

/**
 * The single place this application talks to an LLM (Milestone 5.1).
 *
 * Provider-agnostic by intent, per the blueprint: every AI feature depends
 * on this service's interface, not on any vendor SDK. That is what let the
 * provider swap from Anthropic to OpenAI be this one file rather than five
 * feature modules, and it is why the request/result types above are plain
 * shapes rather than SDK types re-exported.
 *
 * Usage is logged HERE rather than in each feature, so a new AI endpoint
 * (Phase 12 adds four) cannot accidentally ship without metering — the
 * quota guard in Milestone 5.2 reads exactly what this writes.
 */
@Injectable()
export class AiGatewayService {
  private readonly logger = new Logger(AiGatewayService.name);
  private readonly client: OpenAI | null;

  /**
   * GPT-4o mini — cost-effective and more than capable for the short
   * marketing generations here (captions, hashtags, tone rewrites, viral
   * scoring). Deliberately a constant rather than an env var: the prompts in
   * prompts/ are tuned against this model's behaviour, and a silent
   * per-environment model swap would change output quality with nothing in
   * the diff to explain it. Changing models should be a reviewed code change.
   */
  private static readonly MODEL = 'gpt-4o-mini';

  /**
   * Whether a development stub may stand in when the real provider is
   * unavailable. True everywhere EXCEPT production and staging — so a
   * developer can build the AI flows without a billed key, while a real
   * deployment (the Dockerfile sets NODE_ENV=production) never fakes a
   * result and instead returns a clear "configure an AI provider" error.
   */
  private readonly allowDevStub: boolean;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const apiKey = this.configService.get<string>('OPENAI_API_KEY');

    // Optional at boot, same reasoning as Cloudinary and the OAuth
    // credentials (Milestones 2.2/3.2): a developer without an OpenAI key
    // should still be able to run the rest of the app.
    this.client = apiKey ? new OpenAI({ apiKey }) : null;

    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');
    this.allowDevStub = nodeEnv !== 'production' && nodeEnv !== 'staging';
  }

  get isConfigured(): boolean {
    return this.client !== null;
  }

  async generate(request: AiGenerationRequest): Promise<AiGenerationResult> {
    if (!this.client) {
      // No key configured — not an error the app should crash on.
      return this.handleUnavailable(request, 'OPENAI_API_KEY is not set');
    }

    let response: OpenAI.Chat.Completions.ChatCompletion;
    try {
      response = await this.client.chat.completions.create({
        model: AiGatewayService.MODEL,
        max_tokens: request.maxTokens ?? 1024,
        messages: [
          // The trusted instructions go in the system turn; the untrusted
          // design content stays in the user turn (never concatenated into
          // the system prompt), so a design can't rewrite the instructions.
          { role: 'system', content: request.systemPrompt },
          { role: 'user', content: request.userPrompt },
        ],
      });
    } catch (error) {
      // A quota/rate-limit (429) means the provider is reachable but the
      // account can't serve the call — the common "I have a key but no
      // billing" case. Treat it like an unavailable provider so development
      // still works and production gets the actionable message, rather than
      // a generic "try again".
      if (this.isQuotaError(error)) {
        return this.handleUnavailable(request, 'the OpenAI quota is exhausted (429)');
      }

      // Any other provider error: its own message is logged but NOT returned
      // to the client (it can echo prompt content, and the caller can't act
      // on "overloaded" anyway).
      this.logger.error(
        `AI generation failed for ${request.feature}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      throw new ServiceUnavailableException(
        'The AI service is temporarily unavailable. Please try again.',
      );
    }

    const choice = response.choices[0];

    // GPT-4o models surface a safety refusal as a dedicated field rather
    // than as normal content — treat it as its own outcome, not an empty
    // caption.
    if (choice?.message?.refusal) {
      throw new ServiceUnavailableException(
        'The AI declined to generate content for this design. Try adjusting the design or tone.',
      );
    }

    const text = (choice?.message?.content ?? '').trim();

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
      inputTokens: response.usage?.prompt_tokens ?? 0,
      outputTokens: response.usage?.completion_tokens ?? 0,
      model: response.model,
    };
  }

  /** True for an OpenAI quota/rate-limit error (HTTP 429). */
  private isQuotaError(error: unknown): boolean {
    const status = (error as { status?: number } | null)?.status;
    const code = (error as { code?: string } | null)?.code;
    return status === 429 || code === 'insufficient_quota';
  }

  /**
   * Called when the real provider can't serve a request (no key, or a 429
   * quota/rate-limit). Outside production/staging it returns a labelled
   * development stub so the AI flow still works locally without billing; in
   * production it throws a clear, actionable error instead of ever faking a
   * result. Never records usage — a stub isn't a real, billable call.
   */
  private handleUnavailable(
    request: AiGenerationRequest,
    reason: string,
  ): AiGenerationResult {
    if (this.allowDevStub) {
      this.logger.warn(
        `AI provider unavailable (${reason}) — returning a development stub ` +
          `for ${request.feature}. This never happens in production.`,
      );
      return {
        text: DEV_STUB_TEXT[request.feature] ?? DEV_STUB_DEFAULT,
        inputTokens: 0,
        outputTokens: 0,
        model: 'dev-stub',
      };
    }

    throw new ServiceUnavailableException(
      'AI is unavailable — configure an AI provider (set OPENAI_API_KEY with ' +
        'billing) to enable it.',
    );
  }

  /**
   * Never throws. A failed usage write must not fail a generation the user
   * already paid for and received — the row is for quota accounting, and
   * losing one is strictly better than discarding a successful result.
   */
  private async recordUsage(
    request: AiGenerationRequest,
    response: OpenAI.Chat.Completions.ChatCompletion,
  ): Promise<void> {
    try {
      await this.prisma.aIUsageLog.create({
        data: {
          orgId: request.orgId,
          userId: request.userId,
          feature: request.feature,
          inputTokens: response.usage?.prompt_tokens ?? 0,
          outputTokens: response.usage?.completion_tokens ?? 0,
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
