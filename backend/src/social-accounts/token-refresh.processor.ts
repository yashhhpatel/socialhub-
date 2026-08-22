import { Processor, WorkerHost } from '@nestjs/bullmq';

import { SocialTokenService } from './social-token.service';
import { TOKEN_REFRESH_QUEUE } from './token-refresh.constants';

/**
 * Worker for the proactive token-refresh sweep (Phase 20). Runs on the shared
 * Redis connection; the job body just delegates to SocialTokenService, which
 * refreshes each due account and marks any that can't be refreshed as needing
 * reconnection. Errors inside the sweep are per-account and swallowed there, so
 * the job itself only fails on an unexpected infrastructure error.
 */
@Processor(TOKEN_REFRESH_QUEUE)
export class TokenRefreshProcessor extends WorkerHost {
  constructor(private readonly socialTokens: SocialTokenService) {
    super();
  }

  async process(): Promise<void> {
    await this.socialTokens.refreshDueAccounts();
  }
}
